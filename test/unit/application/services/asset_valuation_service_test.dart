@Tags(['application'])
library;

import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/get_settings_use_case_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';

void main() {
  group('AssetValuationService', () {
    late MockGetSettingsUseCase getSettings;
    late MockGetRateAtUseCase getRateAt;
    late AssetValuationService service;

    late AssetId eur;
    late AssetId usd;
    late DateTime at;

    setUp(() {
      getSettings = MockGetSettingsUseCase();
      getRateAt = MockGetRateAtUseCase();

      eur = AssetId.fromString('asset-eur');
      usd = AssetId.fromString('asset-usd');
      at = DateTime.utc(2026, 9, 17, 7, 30);

      final resolveConversionRate = ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: usd,
        rateConversion: const RateConversionService(),
      );

      service = AssetValuationService(
        getSettings: getSettings,
        resolveConversionRate: resolveConversionRate,
        calculator: const AssetValuationCalculator(),
      );
    });

    test('returns an identity valuation when already in valuation currency',
        () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: usd,
        amount: Decimal.parse('125.40'),
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull, same(amount));

      verify(() => getSettings()).called(1);
      verifyZeroInteractions(getRateAt);
    });

    test('converts a known amount using the resolved historical rate', () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('80'),
      );

      final eurUsd = exchangeRateFixture(
        id: 'eur-usd',
        baseAssetId: eur.value,
        quoteAssetId: usd.value,
        rate: '1.25',
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, isNull);

      final valuation = result.valueOrNull!;

      expect(valuation.assetId, usd);
      expect(valuation.amount, Decimal.parse('100'));
      expect(valuation.isIncoming, isTrue);

      verify(() => getSettings()).called(1);
      verify(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).called(1);
    });

    test('preserves outgoing direction after rate conversion', () async {
      // Given
      final amount = AssetAmount.outgoing(
        assetId: eur,
        amount: Decimal.parse('40'),
      );

      final eurUsd = exchangeRateFixture(
        id: 'eur-usd',
        baseAssetId: eur.value,
        quoteAssetId: usd.value,
        rate: '1.25',
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      final valuation = result.valueOrNull!;

      expect(valuation.assetId, usd);
      expect(valuation.amount, Decimal.parse('50'));
      expect(valuation.isOutgoing, isTrue);
    });

    test('values cross-asset zero without resolving a rate', () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.zero,
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, isNull);

      final valuation = result.valueOrNull!;

      expect(valuation.assetId, usd);
      expect(valuation.amount, Decimal.zero);
      expect(valuation.isIncoming, isTrue);

      verifyZeroInteractions(getRateAt);
    });

    test('propagates an unknown amount without resolving a rate', () async {
      // Given
      final amount = AssetAmount.outgoing(
        assetId: eur,
        amount: Decimal.fromInt(-1),
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, isNull);

      final valuation = result.valueOrNull!;

      expect(valuation.assetId, usd);
      expect(valuation.isUnknownAmount, isTrue);
      expect(valuation.isOutgoing, isTrue);

      verifyZeroInteractions(getRateAt);
    });

    test('returns settings-not-initialized when settings are absent', () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => const Success<Settings?>(null),
      );

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(
        result.failureOrNull,
        isA<SettingsNotInitializedFailure>(),
      );

      expect(
        result.failureOrNull?.message,
        'Settings have not been initialized.',
      );

      verifyZeroInteractions(getRateAt);
    });

    test('propagates settings failures unchanged', () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      const failure = SettingsNotInitializedFailure(
        message: 'settings read failed',
      );

      when(
        () => getSettings(),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, same(failure));
      verifyZeroInteractions(getRateAt);
    });

    test('returns an unknown valuation when the conversion rate is missing',
        () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      const failure = RateNotFoundFailure(
        message: 'EUR/USD rate was not found.',
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, isNull);

      final valuation = result.valueOrNull!;

      expect(valuation.assetId, usd);
      expect(valuation.isUnknownAmount, isTrue);
      expect(valuation.isIncoming, isTrue);
    });

    test('propagates non-missing rate failures unchanged', () async {
      // Given
      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      const failure = RateRepositoryFailure(
        message: 'Rate store unavailable.',
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(
        amount: amount,
        at: at,
      );

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('passes the requested valuation instant to rate resolution', () async {
      // Given
      final historicalAt = DateTime.utc(2025, 12, 31, 23, 59);

      final amount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('10'),
      );

      final eurUsd = exchangeRateFixture(
        id: 'historical-eur-usd',
        baseAssetId: eur.value,
        quoteAssetId: usd.value,
        rate: '1.20',
      );

      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: usd),
        ),
      );

      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: historicalAt,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      // When
      final result = await service(
        amount: amount,
        at: historicalAt,
      );

      // Then
      expect(result.valueOrNull?.amount, Decimal.parse('12'));

      verify(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: historicalAt,
        ),
      ).called(1);
    });
  });
}
