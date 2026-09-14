import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Unarchives an account.
final class UnarchiveAccountUseCase {
  /// Creates a use case with its repository and canonical time source.
  const UnarchiveAccountUseCase({
    required AccountRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final AccountRepository _repository;
  final Clock _clock;

  /// Unarchives [id].
  Future<Result<Account, AccountFailure>> call(AccountId id) {
    return _repository.unarchive(id, _clock.nowUtc);
  }
}
