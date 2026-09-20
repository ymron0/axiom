@Tags(['application'])
library;

import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/create_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:decimal/decimal.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../../mocks/jar_repository_mock.dart';
import '../../../../../mocks/settings_repository_mock.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  group('CreateJarUseCase', () {
    late MockJarRepository repository;
    late MockSettingsRepository settingsRepository;
    late MockAssetRepository assetRepository;
    late CreateJarUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 2);

    setUpAll(() {
      registerFallbackValue(jarFixture(id: 'fallback'));
      registerFallbackValue(AssetId.fromString('fallback-asset'));
    });

    setUp(() {
      repository = MockJarRepository();
      settingsRepository = MockSettingsRepository();
      assetRepository = MockAssetRepository();
      useCase = CreateJarUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
        validateTargetCurrencies: ValidateJarTargetCurrenciesService(
          getValuationCurrency: GetValuationCurrencyService(
            getSettings: GetSettingsUseCase(settingsRepository),
            getAssetById: GetAssetByIdUseCase(assetRepository),
          ),
        ),
      );
      when(() => assetRepository.getById(any())).thenAnswer((invocation) async {
        final assetId = invocation.positionalArguments.single as AssetId;
        return Success(currencyFixture(id: assetId.value));
      });
    });

    test('creates an active jar with the injected clock', () async {
      // Given
      final command = createJarCommandFixture(name: '  Holiday fund  ');
      when(() => repository.create(any())).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      final jar = result.valueOrNull!;
      expect(jar.name, 'Holiday fund');
      expect(jar.kind, command.kind);
      expect(jar.icon, command.icon);
      expect(jar.color, command.color);
      expect(jar.sortOrder, command.sortOrder);
      expect(jar.createdAt, timestamp);
      expect(jar.modifiedAt, timestamp);
      expect(jar.entityVersion, 1);
      expect(jar.isArchived, isFalse);
      expect(jar.isDeleted, isFalse);
      verify(() => repository.create(jar)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final command = createJarCommandFixture();
      const failure = JarAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('creates targets using the configured valuation asset', () async {
      // Given
      final valuationAssetId = AssetId.fromString('asset-chf');
      final command = createJarCommandFixture(
        targets: [_target(valuationAssetId)],
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: valuationAssetId)),
      );
      when(() => repository.create(any())).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.create(any())).called(1);
    });

    test('rejects targets using another valuation asset before creation', () async {
      // Given
      final command = createJarCommandFixture(
        targets: [_target(AssetId.fromString('asset-eur'))],
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: AssetId.fromString('asset-chf')),
        ),
      );

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
      verifyNever(() => repository.create(any()));
    });
  });
}

JarTarget _target(AssetId assetId) {
  return JarTarget(
    amount: AssetAmount.incoming(assetId: assetId, amount: Decimal.one),
    effectiveFrom: CalendarDate(2026, 1, 1),
  );
}
