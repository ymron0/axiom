import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_id.mapper.dart';

/// A type-safe identifier for a transaction series.
///
/// Create one from a persisted value:
/// ```dart
/// final transactionSeriesId = TransactionSeriesId.fromString('transaction-series-123');
/// ```
///
/// ## Invariants
///
/// The serialized value is non-empty, not solely whitespace, immutable, and
/// stable for the lifetime of this identifier. Generated values obey the same
/// validation contract. Valid supplied values are preserved exactly without
/// silent trimming or normalization.
///
/// ## Semantics
///
/// The Dart type represents transaction-series identity and must not be
/// substituted for an unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new transaction-series IDs.
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
