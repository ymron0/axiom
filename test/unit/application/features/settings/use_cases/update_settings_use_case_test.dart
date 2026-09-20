@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/application/use_cases/update_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
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

    test('persists a changed overbudget policy', () async {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('asset-chf'),
        allowOverbudgetTransactions: false,
      );

      when(
        () => repository.update(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));

      final result = await useCase(settings);

      expect(result.valueOrNull, same(settings));
      expect(result.valueOrNull?.allowOverbudgetTransactions, isFalse);

      verify(() => repository.update(settings)).called(1);
    });

    test('propagates not-found failures', () async {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('missing-settings'),
      );

      const failure = SettingsNotInitializedFailure(
        message: 'settings not found',
      );

      when(() => repository.update(settings)).thenAnswer((_) async => failure);

      final result = await useCase(settings);

      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('failed-settings-update'),
      );

      const failure = SettingsRepositoryFailure(message: 'update failed');

      when(() => repository.update(settings)).thenAnswer((_) async => failure);

      final result = await useCase(settings);

      expect(result.failureOrNull, same(failure));
    });
  });
}
