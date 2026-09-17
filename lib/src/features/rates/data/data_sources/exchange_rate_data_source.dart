// coverage:ignore-file

import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/data/models/exchange_rate_data_point.dart';

/// External data boundary for obtaining normalized exchange-rate observations.
///
/// The data source accepts domain [Currency] instances rather than arbitrary
/// asset identifiers. This makes the currency-only nature of exchange rates
/// explicit at the boundary.
///
/// Returned observations use the supplied [quoteCurrency] as their quote asset:
///
/// ```text
/// 1 base currency = rate × quote currency
/// ```
///
/// A provider may expose rates using another orientation internally. Concrete
/// implementations are responsible for translating provider semantics into
/// this canonical orientation.
///
/// This contract does not persist rates and does not resolve cross rates.
/// Persistence belongs to repositories/application workflows, while arbitrary
/// pair resolution belongs to the rates calculation services.
abstract interface class ExchangeRateDataSource {
  /// Fetches the latest available observations for [baseCurrencies].
  ///
  /// Every returned observation has:
  ///
  /// ```text
  /// observation.quoteAssetId == quoteCurrency.id
  /// ```
  ///
  /// [quoteCurrency] itself may appear in [baseCurrencies]. It is ignored
  /// because a persisted rate cannot use the same asset as both base and quote.
  ///
  /// Implementations must:
  ///
  /// - preserve internal asset identities;
  /// - preserve financial base/quote orientation;
  /// - use exact decimal arithmetic;
  /// - preserve the provider's effective timestamp;
  /// - return deterministic ordering; and
  /// - never synthesize cross rates.
  Future<List<ExchangeRateDataPoint>> fetchLatest({
    required Currency quoteCurrency,
    required Iterable<Currency> baseCurrencies,
  });
}
