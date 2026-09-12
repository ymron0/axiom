import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_already_deleted_failure.mapper.dart';

/// Indicates that a transaction is already marked as deleted.
@MappableClass()
final class TransactionAlreadyDeletedFailure
    extends Failure<TransactionAlreadyDeletedFailure>
    with TransactionAlreadyDeletedFailureMappable
    implements TransactionFailure {
  /// Creates a transaction-already-deleted failure with optional details.
  const TransactionAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionAlreadyDeleted';

  @override
  TransactionAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
