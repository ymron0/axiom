import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_all_transactions_command.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Atomically creates and persists multiple active transactions.
///
/// If any transaction cannot be stored, none of the transactions are stored.
final class CreateAllTransactionsUseCase {
  /// Creates a use case with its repository and time source.
  const CreateAllTransactionsUseCase({
    required TransactionRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final TransactionRepository _repository;
  final Clock _clock;

  /// Creates and persists every transaction described by [command].
  ///
  /// Returns the created transactions on success, including an empty list for
  /// an empty command, or a [TransactionFailure] without storing any
  /// transaction from the batch when the operation cannot complete.
  Future<Result<List<Transaction>, TransactionFailure>> call(
    CreateAllTransactionsCommand command,
  ) async {
    final transactions = command.commands
        .map(
          (transaction) => Transaction.create(
            kind: transaction.kind,
            merchantId: transaction.merchantId,
            effectiveAt: transaction.effectiveAt,
            description: transaction.description,
            note: transaction.note,
            state: transaction.state,
            splits: transaction.splits,
            ledgerEntries: transaction.ledgerEntries,
            clock: _clock,
          ),
        )
        .toList(growable: false);
    final createResult = await _repository.createAll(transactions);

    return createResult.when<Result<List<Transaction>, TransactionFailure>>(
      success: (_) => Success(transactions),
      failure: (failure) => failure,
    );
  }
}
