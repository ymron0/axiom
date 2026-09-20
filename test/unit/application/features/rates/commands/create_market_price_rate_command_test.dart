@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/commands/create_market_price_rate_command.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CreateMarketPriceRateCommand', () {
    test('retains the supplied market-price rate creation input', () {
      // Given
      final baseAssetId = AssetId.fromString('BTC');
      final quoteAssetId = AssetId.fromString('USD');
      final rate = Decimal.parse('65000.50');
      final effectiveAt = DateTime.utc(2026, 9, 20, 12);

      // When
      final command = CreateMarketPriceRateCommand(
        baseAssetId: baseAssetId,
        quoteAssetId: quoteAssetId,
        rate: rate,
        effectiveAt: effectiveAt,
      );

      // Then
      expect(command.baseAssetId, baseAssetId);
      expect(command.quoteAssetId, quoteAssetId);
      expect(command.rate, rate);
      expect(command.effectiveAt, effectiveAt);
    });
  });
}
