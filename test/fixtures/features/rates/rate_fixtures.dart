import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:decimal/decimal.dart';

/// Builds a deterministic [ExchangeRate] for repository and service tests.
///
/// Defaults to the EUR/USD pair and a UTC effective instant so callers can
/// override only the fields relevant to a scenario.
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

/// Builds a deterministic [MarketPriceRate] for repository and service tests.
///
/// Defaults to the BTC/USD pair and a UTC effective instant so callers can
/// override only the fields relevant to a scenario.
MarketPriceRate marketPriceRateFixture({
  String id = 'rate-market-1',
  String baseAssetId = 'BTC',
  String quoteAssetId = 'USD',
  String rate = '65000.00',
  DateTime? effectiveAt,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final effectiveTimestamp = effectiveAt ?? DateTime.utc(2026, 9, 10);
  return MarketPriceRate(
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
