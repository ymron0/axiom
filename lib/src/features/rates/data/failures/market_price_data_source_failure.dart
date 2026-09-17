// coverage:ignore-file

import 'package:axiom/src/core/failures/base_failure.dart';

/// Base contract for expected failures produced by a market-price data source.
///
/// These failures describe acquisition-layer problems rather than persisted
/// rate or domain failures.
///
/// Examples include:
///
/// - a requested market price not being available;
/// - the underlying provider being unavailable; and
/// - the provider returning data that cannot be interpreted safely.
///
/// Implementations must translate expected provider-specific failures into
/// this contract before exposing them to callers.
abstract interface class MarketPriceDataSourceFailure implements BaseFailure {}
