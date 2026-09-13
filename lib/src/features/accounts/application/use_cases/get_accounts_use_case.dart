import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Retrieves all active persisted accounts.
final class GetAccountsUseCase {
  /// Creates a use case backed by [repository].
  GetAccountsUseCase(this._repository);

  final AccountRepository _repository;

  /// Returns all active persisted accounts.
  ///
  /// Returns an empty list when none exist, or an [AccountFailure] when
  /// retrieval fails.
  Future<Result<List<Account>, AccountFailure>> call() {
    return _repository.getAll();
  }
}
