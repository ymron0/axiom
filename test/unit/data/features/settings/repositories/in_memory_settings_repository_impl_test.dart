import 'package:axiom/src/features/settings/data/repositories/in_memory_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:fixtures/fixtures/settings_fixtures.dart';
import 'package:test/test.dart';

void main() {
  group('InMemorySettingsRepositoryImpl', () {
    test('starts with the fixture settings', () async {
      // Given
      final repository = InMemorySettingsRepositoryImpl();
      final expected = Settings(
        valuationCurrencyId: AssetId.fromString(
          settingsFixtures.first.valuationCurrencyId,
        ),
      );

      // When
      final result = await repository.get();

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, expected);
    });

    test('rejects creation without replacing the fixture settings', () async {
      // Given
      final repository = InMemorySettingsRepositoryImpl();
      final original = (await repository.get()).valueOrNull;
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('asset-usd'),
      );

      // When
      final result = await repository.create(settings);

      // Then
      expect(
        result.failureOrNull,
        isA<SettingsAlreadyInitializedFailure>(),
      );
      expect((await repository.get()).valueOrNull, same(original));
    });

    test('updates initialized settings', () async {
      // Given
      final repository = InMemorySettingsRepositoryImpl();
      final replacement = Settings(
        valuationCurrencyId: AssetId.fromString('asset-usd'),
      );

      // When
      final result = await repository.update(replacement);

      // Then
      expect(result.valueOrNull, same(replacement));
      expect((await repository.get()).valueOrNull, same(replacement));
    });
  });
}
