@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/data/failures/settings_persistence_failure.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late SettingsRepository repository;

  Settings settings(String assetId) {
    return Settings(valuationCurrencyId: AssetId.fromString(assetId));
  }

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastSettingsRepositoryImpl(database: database);
  });

  group('SembastSettingsRepositoryImpl', () {
    test('starts uninitialized', () async {
      // When
      final result = await repository.get();

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('creates and reads settings', () async {
      // Given
      final expected = settings('asset-chf');

      // When
      final result = await repository.create(expected);

      // Then
      expect(result.isSuccess, isTrue);

      final stored = (await repository.get()).valueOrNull;
      expect(stored, isNotNull);
      expect(stored!.valuationCurrencyId, expected.valuationCurrencyId);
    });

    test(
      'returns SettingsAlreadyInitializedFailure without replacement',
      () async {
        // Given
        final original = settings('asset-chf');
        final replacement = settings('asset-usd');

        await repository.create(original);

        // When
        final result = await repository.create(replacement);

        // Then
        expect(result.failureOrNull, isA<SettingsAlreadyInitializedFailure>());

        expect(
          (await repository.get()).valueOrNull?.valuationCurrencyId,
          original.valuationCurrencyId,
        );
      },
    );

    test(
      'returns SettingsNotInitializedFailure when update has no record',
      () async {
        // Given
        final replacement = settings('asset-usd');

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());
      },
    );

    test('updates initialized settings', () async {
      // Given
      await repository.create(settings('asset-chf'));
      final replacement = settings('asset-usd');

      // When
      final result = await repository.update(replacement);

      // Then
      expect(result.isSuccess, isTrue);
      expect(
        (await repository.get()).valueOrNull?.valuationCurrencyId,
        AssetId.fromString('asset-usd'),
      );
    });

    test('allows exactly one concurrent initialization', () async {
      // Given
      final first = settings('asset-chf');
      final second = settings('asset-usd');

      // When
      final results = await Future.wait([
        repository.create(first),
        repository.create(second),
      ]);

      // Then
      expect(results.where((result) => result.isSuccess), hasLength(1));
      expect(
        results.where(
          (result) => result.failureOrNull is SettingsAlreadyInitializedFailure,
        ),
        hasLength(1),
      );
    });

    test('translates malformed persisted settings to typed failure', () async {
      // Given
      await SembastStores.settings
          .record(SembastRecordKeys.settings)
          .put(database, <String, Object?>{});

      // When
      final result = await repository.get();

      // Then
      expect(result.failureOrNull, isA<SettingsPersistenceFailure>());
    });
  });
}
