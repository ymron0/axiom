import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_occurrence_operation_failure.mapper.dart';

/// Indicates that an occurrence-specific transaction operation cannot be
/// completed.
@MappableClass()
final class TransactionOccurrenceOperationFailure
    extends Failure<TransactionOccurrenceOperationFailure>
    with TransactionOccurrenceOperationFailureMappable {
  /// Creates an occurrence-operation failure.
  const TransactionOccurrenceOperationFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'application.transactionOccurrenceOperation';

  @override
  TransactionOccurrenceOperationFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
