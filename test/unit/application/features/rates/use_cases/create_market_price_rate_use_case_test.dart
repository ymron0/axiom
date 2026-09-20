@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/commands/create_market_price_rate_command.dart';
import 'package:axiom/src/features/rates/application/failures/unsupported_persisted_rate_quote_failure.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_market_price_rate_use_case.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/create_rate_service_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(marketPriceRateFixture());
  });

  group('CreateMarketPriceRateUseCase', () {
    late MockCreateRateService createRateService;
    late CreateMarketPriceRateUseCase useCase;
    late DateTime timestamp;

    setUp(() {
      createRateService = MockCreateRateService();
      timestamp = DateTime.utc(2026, 9, 20, 10);
      useCase = CreateMarketPriceRateUseCase(
        createRate: createRateService,
        clock: FixedClock(timestamp),
      );
    });

    test('generates and persists a new market price rate', () async {
      // Given
      final command = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('65000.00'),
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      );
      when(() => createRateService(any())).thenAnswer(
        (invocation) async => Success(
          invocation.positionalArguments.whereType<MarketPriceRate>().first,
        ),
      );

      // When
      final result = await useCase(command);

      // Then
      expect(result.isSuccess, isTrue);
      final marketPriceRate = result.valueOrNull!;
      expect(marketPriceRate.id.value, isNotEmpty);
      expect(marketPriceRate.entityVersion, 1);
      expect(marketPriceRate.createdAt, timestamp);
      expect(marketPriceRate.modifiedAt, same(marketPriceRate.createdAt));
      expect(marketPriceRate.baseAssetId, command.baseAssetId);
      expect(marketPriceRate.quoteAssetId, command.quoteAssetId);
      expect(marketPriceRate.rate, command.rate);
      expect(marketPriceRate.effectiveAt, command.effectiveAt);
      verify(() => createRateService(marketPriceRate)).called(1);
    });

    test('propagates repository failures unchanged', () async {
      // Given
      final command = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('65000.00'),
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      );
      const failure = RateRepositoryFailure(message: 'Storage write failed');
      when(() => createRateService(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => createRateService(any())).called(1);
    });

    test('propagates quote currency validation failures unchanged', () async {
      // Given
      final command = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('EUR'),
        rate: Decimal.parse('60000.00'),
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      );
      const failure = UnsupportedPersistedRateQuoteFailure(
        message: 'Must be quoted in canonical bridge asset',
      );
      when(() => createRateService(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('throws ArgumentError when base and quote assets are identical', () {
      // Given
      final command = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('BTC'),
        rate: Decimal.parse('65000.00'),
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      );

      // When / Then
      expect(() => useCase(command), throwsArgumentError);
      verifyZeroInteractions(createRateService);
    });

    test('throws ArgumentError when rate is zero or negative', () {
      // Given
      final commandZero = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.zero,
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      );
      final commandNegative = CreateMarketPriceRateCommand(
        baseAssetId: AssetId.fromString('BTC'),
        quoteAssetId: AssetId.fromString('USD'),
        rate: Decimal.parse('-1'),
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      );

      // When / Then
      expect(() => useCase(commandZero), throwsArgumentError);
      expect(() => useCase(commandNegative), throwsArgumentError);
      verifyZeroInteractions(createRateService);
    });
  });
}
