import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/commands/create_account_command.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';

/// Creates and persists a new active account.
final class CreateAccountUseCase {
  /// Creates a use case with its repository and time source.
  const CreateAccountUseCase({
    required AccountRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final AccountRepository _repository;
  final Clock _clock;

  /// Creates and persists an account from [command].
  ///
  /// Returns the created account on success or an [AccountFailure].
  Future<Result<Account, AccountFailure>> call(
    CreateAccountCommand command,
  ) async {
    final account = Account.create(
      name: command.name,
      custodianId: command.custodianId,
      denominationAssetId: command.denominationAssetId,
      kind: command.kind,
      reference: command.reference,
      logo: command.logo,
      icon: command.icon,
      color: command.color,
      sortOrder: command.sortOrder,
      clock: _clock,
    );
    final createResult = await _repository.create(account);

    return createResult.when<Result<Account, AccountFailure>>(
      success: (_) => Success(account),
      failure: (failure) => failure,
    );
  }
}
