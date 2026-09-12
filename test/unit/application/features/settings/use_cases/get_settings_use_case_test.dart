import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('GetSettingsUseCase', () {
    late MockSettingsRepository repository;
    late GetSettingsUseCase useCase;

    setUp(() {
      repository = MockSettingsRepository();
      useCase = GetSettingsUseCase(repository);
    });

    test('returns the persisted settings', () async {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('get-settings'),
      );
      when(
        () => repository.get(),
      ).thenAnswer((_) async => Success<Settings?>(settings));

      // When
      final result = await useCase.call();

      // Then
      expect(result.valueOrNull, same(settings));
      verify(() => repository.get()).called(1);
    });

    test('returns null when settings are not initialized', () async {
      // Given
      when(
        () => repository.get(),
      ).thenAnswer((_) async => const Success<Settings?>(null));

      // When
      final result = await useCase.call();

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
      verify(() => repository.get()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = SettingsPersistenceFailure(message: 'read failed');
      when(() => repository.get()).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
