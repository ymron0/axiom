import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/application/use_cases/update_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('UpdateSettingsUseCase', () {
    late MockSettingsRepository repository;
    late UpdateSettingsUseCase useCase;

    setUp(() {
      repository = MockSettingsRepository();
      useCase = UpdateSettingsUseCase(repository);
    });

    test('returns the updated settings', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('update-settings'),
      );
      when(
        () => repository.update(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));

      // When
      final result = await useCase.call(settings);

      // Then
      expect(result.valueOrNull, same(settings));
      verify(() => repository.update(settings)).called(1);
    });

    test('propagates not-found failures', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('missing-settings'),
      );
      const failure = SettingsNotInitializedFailure(
        message: 'settings not found',
      );
      when(() => repository.update(settings)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(settings);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('failed-settings-update'),
      );
      const failure = SettingsPersistenceFailure(message: 'update failed');
      when(() => repository.update(settings)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(settings);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
