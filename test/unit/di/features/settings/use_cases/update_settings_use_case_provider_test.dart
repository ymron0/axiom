@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:axiom/src/features/settings/di/update_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('updateSettingsUseCaseProvider', () {
    test('uses the configured settings repository', () async {
      final repository = MockSettingsRepository();

      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('asset-chf'),
        allowOverbudgetTransactions: false,
      );

      when(
        () => repository.update(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));

      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );

      addTearDown(container.dispose);

      final result = await container
          .read(updateSettingsUseCaseProvider)
          .call(settings);

      expect(result.valueOrNull, same(settings));

      verify(() => repository.update(settings)).called(1);
    });
  });
}
