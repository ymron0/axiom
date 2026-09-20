@Tags(['application'])
library;

import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';

void main() {
  late MockGetRateAtUseCase getRateAt;
  late ValueAssetAmountsService service;

  final chf = AssetId.fromString('asset-chf');
  final eur = AssetId.fromString('asset-eur');
  final usd = AssetId.fromString('asset-usd');
  final at = DateTime.utc(2026, 9, 20, 12);

  setUp(() {
    getRateAt = MockGetRateAtUseCase();

    service = ValueAssetAmountsService(
      resolveConversionRate: ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: chf,
        rateConversion: const RateConversionService(),
      ),
      calculator: const AssetValuationCalculator(),
    );
  });

  test('returns zero target amount for an empty collection', () async {
    final result = await service(amounts: const [], targetAssetId: chf, at: at);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.assetId, chf);
    expect(result.valueOrNull!.amount, Decimal.zero);
    expect(result.valueOrNull!.isIncoming, isTrue);
  });

  test('nets same-asset incoming and outgoing amounts', () async {
    final result = await service(
      amounts: [
        AssetAmount.incoming(assetId: chf, amount: Decimal.parse('100')),
        AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('25')),
      ],
      targetAssetId: chf,
      at: at,
    );

    expect(result.valueOrNull!.assetId, chf);
    expect(result.valueOrNull!.amount, Decimal.parse('75'));
    expect(result.valueOrNull!.isIncoming, isTrue);
  });

  test('values and aggregates several foreign assets', () async {
    when(
      () => getRateAt(baseAssetId: usd, quoteAssetId: chf, at: at),
    ).thenAnswer(
      (_) async => Success(
        exchangeRateFixture(
          id: 'usd-chf',
          baseAssetId: usd.value,
          quoteAssetId: chf.value,
          rate: '0.9',
        ),
      ),
    );

    when(
      () => getRateAt(baseAssetId: eur, quoteAssetId: chf, at: at),
    ).thenAnswer(
      (_) async => Success(
        exchangeRateFixture(
          id: 'eur-chf',
          baseAssetId: eur.value,
          quoteAssetId: chf.value,
          rate: '0.95',
        ),
      ),
    );

    final result = await service(
      amounts: [
        AssetAmount.incoming(assetId: usd, amount: Decimal.parse('100')),
        AssetAmount.outgoing(assetId: eur, amount: Decimal.parse('20')),
      ],
      targetAssetId: chf,
      at: at,
    );

    // 100 USD * 0.9 - 20 EUR * 0.95 = 71 CHF.
    expect(result.valueOrNull!.assetId, chf);
    expect(result.valueOrNull!.amount, Decimal.parse('71'));
    expect(result.valueOrNull!.isIncoming, isTrue);
  });

  test(
    'returns an outgoing aggregate when the signed total is negative',
    () async {
      final result = await service(
        amounts: [
          AssetAmount.incoming(assetId: chf, amount: Decimal.parse('25')),
          AssetAmount.outgoing(assetId: chf, amount: Decimal.parse('50')),
        ],
        targetAssetId: chf,
        at: at,
      );

      expect(result.valueOrNull!.amount, Decimal.parse('25'));
      expect(result.valueOrNull!.isOutgoing, isTrue);
    },
  );

  test('propagates missing conversion rate', () async {
    when(
      () => getRateAt(baseAssetId: usd, quoteAssetId: chf, at: at),
    ).thenAnswer(
      (_) async => const RateNotFoundFailure(message: 'missing USD/CHF'),
    );

    final result = await service(
      amounts: [
        AssetAmount.incoming(assetId: usd, amount: Decimal.parse('100')),
      ],
      targetAssetId: chf,
      at: at,
    );

    expect(result.failureOrNull, isA<RateNotFoundFailure>());
  });

  test('rejects unknown amounts', () async {
    final unknown = AssetAmount.incoming(
      assetId: usd,
      amount: Decimal.fromInt(-1),
    );

    await expectLater(
      service(amounts: [unknown], targetAssetId: chf, at: at),
      throwsA(
        isA<ArgumentError>().having((error) => error.name, 'name', 'amounts'),
      ),
    );
  });
}
