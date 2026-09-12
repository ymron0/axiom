import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/application/use_cases/create_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('CreateSettingsUseCase', () {
    late MockSettingsRepository repository;
    late CreateSettingsUseCase useCase;

    setUp(() {
      repository = MockSettingsRepository();
      useCase = CreateSettingsUseCase(repository);
    });

    test('returns the created settings', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('create-settings'),
      );
      when(
        () => repository.create(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));

      // When
      final result = await useCase.call(settings);

      // Then
      expect(result.valueOrNull, same(settings));
      verify(() => repository.create(settings)).called(1);
    });

    test('propagates duplicate failures', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('duplicate-settings'),
      );
      const failure = SettingsAlreadyInitializedFailure(
        message: 'settings exist',
      );
      when(() => repository.create(settings)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(settings);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('failed-settings'),
      );
      const failure = SettingsPersistenceFailure(message: 'write failed');
      when(() => repository.create(settings)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(settings);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
