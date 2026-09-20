@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late SettingsRepository repository;

  Settings settings(String assetId, {bool allowOverbudgetTransactions = true}) {
    return Settings(
      valuationCurrencyId: AssetId.fromString(assetId),
      allowOverbudgetTransactions: allowOverbudgetTransactions,
    );
  }

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastSettingsRepositoryImpl(database: database);
  });

  group('SembastSettingsRepositoryImpl', () {
    test('starts uninitialized', () async {
      final result = await repository.get();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('creates and reads settings including budget policy', () async {
      final expected = settings(
        'asset-chf',
        allowOverbudgetTransactions: false,
      );

      final result = await repository.create(expected);

      expect(result.isSuccess, isTrue);

      final stored = (await repository.get()).valueOrNull;

      expect(stored, isNotNull);
      expect(stored!.valuationCurrencyId, expected.valuationCurrencyId);
      expect(stored.allowOverbudgetTransactions, isFalse);
    });

    test('reads legacy settings without the policy as permissive', () async {
      await SembastStores.settings.record(SembastRecordKeys.settings).put(
        database,
        <String, Object?>{'valuationCurrencyId': 'asset-chf'},
      );

      final result = await repository.get();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.allowOverbudgetTransactions, isTrue);
    });

    test(
      'returns SettingsAlreadyInitializedFailure without replacement',
      () async {
        final original = settings('asset-chf');
        final replacement = settings(
          'asset-usd',
          allowOverbudgetTransactions: false,
        );

        await repository.create(original);

        final result = await repository.create(replacement);

        expect(result.failureOrNull, isA<SettingsAlreadyInitializedFailure>());

        final stored = (await repository.get()).valueOrNull!;

        expect(stored.valuationCurrencyId, original.valuationCurrencyId);
        expect(stored.allowOverbudgetTransactions, isTrue);
      },
    );

    test(
      'returns SettingsNotInitializedFailure when update has no record',
      () async {
        final replacement = settings(
          'asset-chf',
          allowOverbudgetTransactions: false,
        );

        final result = await repository.update(replacement);

        expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());
      },
    );

    test('updates the overbudget policy', () async {
      await repository.create(
        settings('asset-chf', allowOverbudgetTransactions: true),
      );

      final replacement = settings(
        'asset-chf',
        allowOverbudgetTransactions: false,
      );

      final result = await repository.update(replacement);

      expect(result.isSuccess, isTrue);

      final stored = (await repository.get()).valueOrNull!;

      expect(stored.valuationCurrencyId, AssetId.fromString('asset-chf'));
      expect(stored.allowOverbudgetTransactions, isFalse);
    });

    test('allows exactly one concurrent initialization', () async {
      final first = settings('asset-chf');
      final second = settings('asset-usd');

      final results = await Future.wait([
        repository.create(first),
        repository.create(second),
      ]);

      expect(results.where((result) => result.isSuccess), hasLength(1));

      expect(
        results.where(
          (result) => result.failureOrNull is SettingsAlreadyInitializedFailure,
        ),
        hasLength(1),
      );
    });

    test('translates malformed persisted settings to typed failure', () async {
      await SembastStores.settings
          .record(SembastRecordKeys.settings)
          .put(database, <String, Object?>{});

      final result = await repository.get();

      expect(result.failureOrNull, isA<SettingsRepositoryFailure>());
    });

    test('translates malformed budget policy to typed failure', () async {
      await SembastStores.settings.record(SembastRecordKeys.settings).put(
        database,
        <String, Object?>{
          'valuationCurrencyId': 'asset-chf',
          'allowOverbudgetTransactions': 'no',
        },
      );

      final result = await repository.get();

      expect(result.failureOrNull, isA<SettingsRepositoryFailure>());
    });
  });
}
