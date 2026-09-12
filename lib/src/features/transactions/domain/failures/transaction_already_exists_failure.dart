import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_already_exists_failure.mapper.dart';

/// Indicates that a transaction conflicts with an existing transaction.
@MappableClass()
final class TransactionAlreadyExistsFailure
    extends Failure<TransactionAlreadyExistsFailure>
    with TransactionAlreadyExistsFailureMappable
    implements TransactionFailure {
  /// Creates a transaction-already-exists failure with optional details.
  const TransactionAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionAlreadyExists';

  @override
  TransactionAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
