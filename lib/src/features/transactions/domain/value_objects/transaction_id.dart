import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_id.mapper.dart';

/// A type-safe identifier for a transaction.
///
/// Create one from a persisted value:
/// ```dart
/// final transactionId = TransactionId.fromString('transaction-123');
/// ```
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
