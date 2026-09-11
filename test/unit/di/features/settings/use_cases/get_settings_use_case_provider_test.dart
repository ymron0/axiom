import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('getSettingsUseCaseProvider', () {
    test('uses the configured settings repository', () async {
      // Given
      final repository = MockSettingsRepository();
      when(
        () => repository.get(),
      ).thenAnswer((_) async => const Success<Settings?>(null));
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(getSettingsUseCaseProvider).call();

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
      verify(() => repository.get()).called(1);
    });
  });
}
