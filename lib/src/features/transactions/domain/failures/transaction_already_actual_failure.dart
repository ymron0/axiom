import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_already_actual_failure.mapper.dart';

/// Indicates that an operation requiring a planned transaction targeted a
/// transaction that is already actual.
@MappableClass()
final class TransactionAlreadyActualFailure
    extends Failure<TransactionAlreadyActualFailure>
    with TransactionAlreadyActualFailureMappable
    implements TransactionFailure {
  /// Creates an already-actual failure with optional operation context.
  const TransactionAlreadyActualFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionAlreadyActual';

  @override
  TransactionAlreadyActualFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
