@Tags(['application'])
library;

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/failures/rate_source_acquisition_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/ports/market_price_source_adapter.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';

final class _TestMarketPriceSourceAdapter implements MarketPriceSourceAdapter {
  Result<RateSourceObservation, BaseFailure> response;

  _TestMarketPriceSourceAdapter(this.response);

  @override
  Future<Result<RateSourceObservation, BaseFailure>> fetchLatest({
    required Asset baseAsset,
    required Currency quoteCurrency,
  }) async {
    return response;
  }
}

void main() {
  group('MarketPriceSourceAdapter', () {
    late CryptoAsset btc;
    late Currency usd;

    setUp(() {
      btc = cryptoAssetFixture(id: 'asset-btc', code: 'BTC');
      usd = currencyFixture(id: 'asset-usd', code: 'USD');
    });

    test(
      'fulfills the interface contract when returning an observation',
      () async {
        // Given
        final observation = RateSourceObservation(
          rate: Decimal.parse('65000'),
          effectiveAt: DateTime.utc(2026, 9, 20),
        );
        final adapter = _TestMarketPriceSourceAdapter(Success(observation));

        // When
        final result = await adapter.fetchLatest(
          baseAsset: btc,
          quoteCurrency: usd,
        );

        // Then
        expect(result.valueOrNull, observation);
      },
    );

    test('fulfills the interface contract when returning a failure', () async {
      // Given
      const failure = RateSourceAcquisitionFailure(message: 'Fetch failed');
      final adapter = _TestMarketPriceSourceAdapter(failure);

      // When
      final result = await adapter.fetchLatest(
        baseAsset: btc,
        quoteCurrency: usd,
      );

      // Then
      expect(result.failureOrNull, failure);
    });
  });
}
