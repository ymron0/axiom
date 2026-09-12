import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/di/create_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('createSettingsUseCaseProvider', () {
    test('uses the configured settings repository', () async {
      // Given
      final repository = MockSettingsRepository();
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('provider-settings'),
      );
      when(
        () => repository.create(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container
          .read(createSettingsUseCaseProvider)
          .call(settings);

      // Then
      expect(result.valueOrNull, same(settings));
      verify(() => repository.create(settings)).called(1);
    });
  });
}
