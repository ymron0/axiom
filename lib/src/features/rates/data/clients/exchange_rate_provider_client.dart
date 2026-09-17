// coverage:ignore-file

import 'package:axiom/src/features/rates/data/models/exchange_rate_provider_snapshot.dart';

/// Provider-facing client used by the exchange-rate data source.
///
/// This interface deliberately contains no domain [AssetId] values. External
/// providers identify currencies by codes such as `USD`, `EUR`, and `CHF`.
///
/// Implementations may use HTTP, local fixtures, platform APIs, or another
/// transport without changing the data-source calculation semantics.
abstract interface class ExchangeRateProviderClient {
  /// Loads the latest provider snapshot.
  ///
  /// [baseCurrencyCode] and every value in [quoteCurrencyCodes] are normalized
  /// uppercase currency codes.
  ///
  /// [quoteCurrencyCodes] is sorted and contains no duplicates.
  ///
  /// The returned snapshot uses provider orientation:
  ///
  /// ```text
  /// 1 baseCurrencyCode
  ///   = quoteUnitsPerBaseUnit[quoteCode] × quoteCode
  /// ```
  Future<ExchangeRateProviderSnapshot> fetchLatest({
    required String baseCurrencyCode,
    required List<String> quoteCurrencyCodes,
  });
}
