// coverage:ignore-file

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';

/// Application-facing boundary for retrieving normalized exchange rates.
///
/// Provider-specific HTTP DTOs, JSON field names, symbol mapping, reciprocal
/// handling, and other normalization remain behind this boundary.
///
/// The application passes complete [Currency] entities so the adapter can use
/// their provider-facing asset codes without reconstructing asset identity
/// from strings.
///
/// Implementations must preserve the requested orientation:
///
/// ```text
/// 1 baseCurrency = rate × quoteCurrency
/// ```
///
/// They must never silently return the inverse orientation.
abstract interface class ExchangeRateSourceAdapter {
  /// Fetches the latest normalized observation for the requested currency pair.
  Future<Result<RateSourceObservation, BaseFailure>> fetchLatest({
    required Currency baseCurrency,
    required Currency quoteCurrency,
  });
}
