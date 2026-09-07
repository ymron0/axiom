import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_id.mapper.dart';

/// A type-safe identifier for a transaction series.
///
/// Create one from a persisted value:
/// ```dart
/// final transactionSeriesId = TransactionSeriesId.fromString('transaction-series-123');
/// ```
@MappableClass()
final class TransactionSeriesId extends UniqueId
    with TransactionSeriesIdMappable {
  /// Creates a transaction series identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  TransactionSeriesId.fromString(super.value);

  /// Creates a transaction series identifier with a newly generated Nano ID value.
  TransactionSeriesId.generate() : super.generate();
}
