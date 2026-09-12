import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Creates and persists one active transaction.
final class CreateTransactionUseCase {
  /// Creates a use case with its repository and time source.
  const CreateTransactionUseCase({
    required TransactionRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final TransactionRepository _repository;
  final Clock _clock;

  /// Creates and persists a transaction from [command].
  ///
  /// Returns the created transaction on success or a [TransactionFailure].
  Future<Result<Transaction, TransactionFailure>> call(
    CreateTransactionCommand command,
  ) async {
    final transaction = Transaction.create(
      kind: command.kind,
      merchantId: command.merchantId,
      effectiveAt: command.effectiveAt,
      description: command.description,
      note: command.note,
      state: command.state,
      splits: command.splits,
      ledgerEntries: command.ledgerEntries,
      clock: _clock,
    );
    final createResult = await _repository.create(transaction);

    return createResult.when<Result<Transaction, TransactionFailure>>(
      success: (_) => Success(transaction),
      failure: (failure) => failure,
    );
  }
}
