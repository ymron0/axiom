import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_id.mapper.dart';

/// A type-safe identifier for a transaction.
///
/// Create one from a persisted value:
/// ```dart
/// final transactionId = TransactionId.fromString('transaction-123');
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
/// The Dart type represents transaction identity and must not be substituted
/// for an unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new transaction IDs.
@MappableClass()
final class TransactionId extends UniqueId with TransactionIdMappable {
  /// Creates a transaction identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  TransactionId.fromString(super.value);

  /// Creates a transaction identifier with a newly generated Nano ID value.
  TransactionId.generate() : super.generate();
}
