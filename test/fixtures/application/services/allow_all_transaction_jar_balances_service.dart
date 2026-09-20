import 'package:axiom/src/application/services/validate_transaction_jar_balances_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Jar-balance validator used where jar-balance policy is outside the test's
/// scope.
class AllowAllTransactionJarBalancesService
    implements ValidateTransactionJarBalancesService {
  /// Creates the permissive test validator.
  const AllowAllTransactionJarBalancesService();

  @override
  Future<Result<void, BaseFailure>> call(
    Transaction transaction, {
    Transaction? previous,
  }) async {
    return const Success(null);
  }
}
