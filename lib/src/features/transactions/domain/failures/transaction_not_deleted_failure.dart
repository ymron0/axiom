import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_not_deleted_failure.mapper.dart';

/// Indicates that a transaction cannot be restored because it is not deleted.
@MappableClass()
final class TransactionNotDeletedFailure
    extends Failure<TransactionNotDeletedFailure>
    with TransactionNotDeletedFailureMappable
    implements TransactionFailure {
  /// Creates a transaction-not-deleted failure with optional details.
  const TransactionNotDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionNotDeleted';

  @override
  TransactionNotDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
