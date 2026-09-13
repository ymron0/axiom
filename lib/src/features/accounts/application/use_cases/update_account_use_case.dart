import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Replaces one active persisted account snapshot.
final class UpdateAccountUseCase {
  /// Creates a use case backed by [repository].
  UpdateAccountUseCase(this._repository);

  final AccountRepository _repository;

  /// Replaces the persisted snapshot for [account].
  ///
  /// Returns an [AccountFailure] when the account is deleted or absent from
  /// persistence.
  Future<Result<void, AccountFailure>> call(Account account) {
    return _repository.update(account);
  }
}
