import 'package:decimal/decimal.dart';

/// A normalized rate observation received from an external data source.
///
/// This value deliberately does not contain local asset IDs.
///
/// Asset identity is owned by the application. The external source supplies
/// only the financial observation for the asset pair that was explicitly
/// requested.
///
/// ## Semantics
///
/// [rate] means:
///
/// ```text
/// 1 requested base asset = rate × requested quote asset
/// ```
///
/// [effectiveAt] is the instant at which the provider says the observation is
/// financially applicable. It is not the time at which the application
/// downloaded or cached the observation.
///
/// ## Invariants
///
/// - [rate] is strictly positive;
/// - [effectiveAt] is stored in UTC.
final class RateSourceObservation {
  /// The normalized source rate.
  final Decimal rate;

  /// The financial effective instant reported by the source.
  final DateTime effectiveAt;

  /// Creates a normalized source observation.
  RateSourceObservation({required Decimal rate, required DateTime effectiveAt})
    : rate = _validateRate(rate),
      effectiveAt = effectiveAt.toUtc();

  static Decimal _validateRate(Decimal rate) {
    if (rate <= Decimal.zero) {
      throw ArgumentError.value(
        rate,
        'rate',
        'Source rate must be greater than zero.',
      );
    }

    return rate;
  }
}
