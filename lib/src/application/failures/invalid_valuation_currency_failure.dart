import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_valuation_currency_failure.mapper.dart';

/// Indicates that an asset cannot be used as the valuation currency.
@MappableClass()
final class InvalidValuationCurrencyFailure
    extends Failure<InvalidValuationCurrencyFailure>
    with InvalidValuationCurrencyFailureMappable {
  /// Creates a failure explaining why the valuation currency is invalid.
  const InvalidValuationCurrencyFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.invalidValuationCurrency';

  @override
  InvalidValuationCurrencyFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
