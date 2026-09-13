import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Retrieves an active persisted account by identifier.
final class GetAccountByIdUseCase {
  /// Creates a use case backed by [repository].
  GetAccountByIdUseCase(this._repository);

  final AccountRepository _repository;

  /// Returns the active account matching [id], or `null` when absent.
  Future<Result<Account?, AccountFailure>> call(AccountId id) {
    return _repository.getById(id);
  }
}
