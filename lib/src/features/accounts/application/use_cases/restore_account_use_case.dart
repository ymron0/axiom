import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Restores a caller-retained, physically deleted account snapshot.
final class RestoreAccountUseCase {
  /// Creates a use case backed by [repository].
  RestoreAccountUseCase(this._repository);

  final AccountRepository _repository;

  /// Restores [account] as an active persisted account.
  ///
  /// Returns an [AccountFailure] when the snapshot is active already or its
  /// identity is already persisted.
  Future<Result<void, AccountFailure>> call(Account account) {
    return _repository.restore(account);
  }
}
