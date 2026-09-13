import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Searches active persisted accounts by name.
final class SearchAccountsUseCase {
  /// Creates a use case backed by [repository].
  SearchAccountsUseCase(this._repository);

  final AccountRepository _repository;

  /// Returns active accounts matching [query].
  ///
  /// Matching and empty-query semantics are defined by the repository.
  Future<Result<List<Account>, AccountFailure>> call(String query) {
    return _repository.search(query);
  }
}
