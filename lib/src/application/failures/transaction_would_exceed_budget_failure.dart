import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_would_exceed_budget_failure.mapper.dart';

/// Indicates that strict budget enforcement rejected a transaction because it
/// would worsen an applicable category budget beyond its configured limit.
@MappableClass()
final class TransactionWouldExceedBudgetFailure
    extends Failure<TransactionWouldExceedBudgetFailure>
    with TransactionWouldExceedBudgetFailureMappable {
  /// Stable identifier for this failure kind.
  static const typeId = 'application.transactionWouldExceedBudget';

  /// Creates a budget-exceeded failure.
  const TransactionWouldExceedBudgetFailure({required String message})
    : super(message);

  @override
  TransactionWouldExceedBudgetFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
