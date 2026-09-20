// coverage:ignore-file

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';

/// Application-facing boundary for retrieving normalized market prices.
///
/// The base asset is a non-currency market-priced Asset.
///
/// The quote asset is a Currency, normally the canonical persisted-rate
/// bridge currency.
///
/// Provider-specific identifiers, DTOs, network semantics, and error handling
/// remain behind this boundary.
abstract interface class MarketPriceSourceAdapter {
  /// Retrieves the latest normalized observation for the requested pair.
  Future<Result<RateSourceObservation, BaseFailure>> fetchLatest({
    required Asset baseAsset,
    required Currency quoteCurrency,
  });
}