import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'exchange_rate.mapper.dart';

/// A rate expressing the exchange relationship between two currencies.
///
/// An [ExchangeRate] specializes [Rate] for currency-to-currency pairs.
///
/// The inherited base/quote semantics apply unchanged:
///
/// ```text
/// 1 base currency = rate × quote currency
/// ```
///
/// For example, an EUR/USD exchange rate of `1.18` means:
///
/// ```text
/// 1 EUR = 1.18 USD
/// ```
///
/// EUR is therefore the [baseAssetId], while USD is the [quoteAssetId].
///
/// The terms "base" and "quote" are financial pair terminology and are
/// unrelated to the application's configured valuation currency.
///
/// ## Invariants
///
/// In addition to the invariants defined by [Rate]:
///
/// - the base asset must represent a currency;
/// - the quote asset must represent a currency.
///
/// Because this entity stores typed [AssetId] references rather than complete
/// Asset instances, verifying that those IDs actually refer to Currency
/// entities requires external domain context. That validation belongs at the
/// construction/use-case boundary where the referenced Assets are available.
///
/// ## Semantics
///
/// An exchange rate represents one observed currency relationship at
/// [effectiveAt].
///
/// Reversing the pair changes its meaning. EUR/USD and USD/EUR are distinct
/// observations whose rates are reciprocals, subject to the precision and
/// source of the underlying data.
///
/// ## Contract
///
/// [ExchangeRate] does not perform currency conversion, inversion, rate
/// selection, interpolation, or lookup. Those behaviors belong to dedicated
/// domain/application services.
@MappableClass()
final class ExchangeRate extends Rate with ExchangeRateMappable {
  /// Creates an exchange-rate observation.
  ///
  /// The common [Rate] invariants validate:
  ///
  /// - distinct base and quote assets;
  /// - a strictly positive rate;
  /// - rate identity;
  /// - effective-time semantics; and
  /// - entity audit metadata.
  ///
  /// Validation that [baseAssetId] and [quoteAssetId] reference currencies
  /// requires access to the corresponding Asset entities and is therefore
  /// performed outside this value itself.
  ExchangeRate({
    required super.id,
    required super.baseAssetId,
    required super.quoteAssetId,
    required super.rate,
    required super.effectiveAt,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
  });
}
