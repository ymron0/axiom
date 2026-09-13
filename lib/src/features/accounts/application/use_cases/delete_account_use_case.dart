import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Physically deletes an account and returns its deleted snapshot.
final class DeleteAccountUseCase {
  /// Creates a use case backed by [repository].
  DeleteAccountUseCase(this._repository);

  final AccountRepository _repository;

  /// Deletes the account identified by [id].
  ///
  /// Returns the caller-retained deleted snapshot or an [AccountFailure].
  Future<Result<Account, AccountFailure>> call(AccountId id) {
    return _repository.delete(id);
  }
}
