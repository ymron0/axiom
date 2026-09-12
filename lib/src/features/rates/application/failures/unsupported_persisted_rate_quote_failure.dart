import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'unsupported_persisted_rate_quote_failure.mapper.dart';

/// Indicates that a persisted rate uses an unsupported quote asset.
@MappableClass()
final class UnsupportedPersistedRateQuoteFailure
    extends Failure<UnsupportedPersistedRateQuoteFailure>
    with UnsupportedPersistedRateQuoteFailureMappable {
  /// Creates a failure explaining why the persisted quote is unsupported.
  const UnsupportedPersistedRateQuoteFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.unsupportedPersistedRateQuote';

  @override
  UnsupportedPersistedRateQuoteFailure get failureOrNull => this;

  @override
  String get type => typeId;
}