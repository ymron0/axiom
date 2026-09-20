import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Budget validator used where budget policy is outside the test's scope.
class AllowAllTransactionBudgetsService
    implements ValidateTransactionBudgetsService {
  /// Creates the permissive test validator.
  const AllowAllTransactionBudgetsService();

  @override
  Future<Result<void, BaseFailure>> call(
    Transaction transaction, {
    Transaction? previous,
  }) async {
    return const Success(null);
  }
}
