import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';
import 'package:decimal/decimal.dart';

/// Creates a reusable exchange-rate fixture for repository tests.
ExchangeRate exchangeRateFixture({
  String id = 'rate-1',
  String baseAssetId = 'EUR',
  String quoteAssetId = 'USD',
  String rate = '1.10',
  DateTime? effectiveAt,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final effectiveTimestamp = effectiveAt ?? DateTime.utc(2026, 9, 10);
  return ExchangeRate(
    id: RateId.fromString(id),
    baseAssetId: AssetId.fromString(baseAssetId),
    quoteAssetId: AssetId.fromString(quoteAssetId),
    rate: Decimal.parse(rate),
    effectiveAt: effectiveTimestamp,
    entityVersion: entityVersion,
    createdAt: createdAt ?? effectiveTimestamp,
    modifiedAt: modifiedAt ?? createdAt ?? effectiveTimestamp,
  );
}
