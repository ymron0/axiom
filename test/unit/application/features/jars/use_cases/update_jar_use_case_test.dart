@Tags(['application'])
library;

import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/application/use_cases/update_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';
import '../../../../../mocks/settings_repository_mock.dart';

void main() {
  group('UpdateJarUseCase', () {
    late MockJarRepository repository;
    late MockSettingsRepository settingsRepository;
    late UpdateJarUseCase useCase;

    setUp(() {
      repository = MockJarRepository();
      settingsRepository = MockSettingsRepository();
      useCase = UpdateJarUseCase(
        repository: repository,
        validateTargetCurrencies: ValidateJarTargetCurrenciesService(
          getSettings: GetSettingsUseCase(settingsRepository),
        ),
      );
    });

    test('updates an active jar', () async {
      // Given
      final jar = jarFixture(id: 'update');
      when(() => repository.update(jar)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(jar);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(jar)).called(1);
    });

    test('rejects a deleted jar without updating it', () async {
      // Given
      final jar = jarFixture(
        id: 'deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, isA<JarAlreadyDeletedFailure>());
      verifyNever(() => repository.update(jar));
    });

    test('propagates repository failures', () async {
      // Given
      final jar = jarFixture(id: 'missing');
      const failure = JarNotFoundFailure(message: 'missing');
      when(() => repository.update(jar)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('updates targets using the configured valuation asset', () async {
      // Given
      final valuationAssetId = AssetId.fromString('asset-chf');
      final jar = jarFixture(
        id: 'update-valuation-asset',
        targets: [_target(valuationAssetId)],
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: valuationAssetId)),
      );
      when(() => repository.update(jar)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(jar);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(jar)).called(1);
    });

    test('rejects targets using another valuation asset before updating', () async {
      // Given
      final jar = jarFixture(
        id: 'update-other-valuation-asset',
        targets: [_target(AssetId.fromString('asset-eur'))],
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: AssetId.fromString('asset-chf')),
        ),
      );

      // When
      final result = await useCase(jar);

      // Then
      expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
      verifyNever(() => repository.update(jar));
    });
  });
}

JarTarget _target(AssetId assetId) {
  return JarTarget(
    amount: AssetAmount.incoming(assetId: assetId, amount: Decimal.one),
    effectiveFrom: CalendarDate(2026, 1, 1),
  );
}
