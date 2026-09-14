import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Returns persisted accounts that are not archived.
final class GetActiveAccountsUseCase {
  /// Creates a use case backed by [repository].
  GetActiveAccountsUseCase(this._repository);

  final AccountRepository _repository;

  /// Returns every unarchived persisted account.
  Future<Result<List<Account>, AccountFailure>> call() {
    return _repository.getActive();
  }
}
