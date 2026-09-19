import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';

/// Removes tag metadata from an existing transaction.
///
/// Removal is idempotent.
///
/// The tag entity itself is deliberately not resolved. This allows an orphaned
/// reference caused by legacy or damaged data to be removed safely.
final class RemoveTagFromTransactionService {
  final Clock _clock;
  final GetTransactionByIdUseCase _getTransactionById;
  final UpdateTransactionUseCase _updateTransaction;

  /// Creates a tag-removal workflow.
  const RemoveTagFromTransactionService({
    required Clock clock,
    required GetTransactionByIdUseCase getTransactionById,
    required UpdateTransactionUseCase updateTransaction,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _updateTransaction = // ignore: prefer_initializing_formals
           updateTransaction;

  /// Removes [tagId] from [transactionId].
  Future<Result<Transaction, BaseFailure>> call({
    required TransactionId transactionId,
    required TagId tagId,
  }) async {
    final transactionResult = await _getTransactionById(transactionId);

    if (transactionResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final transaction = transactionResult.valueOrNull;

    if (transaction == null) {
      return TransactionNotFoundFailure(
        message: 'Transaction ID was not found: ${transactionId.value}',
      );
    }

    if (!transaction.tagIds.contains(tagId)) {
      return Success(transaction);
    }

    final updated = transaction.copyWith(
      tagIds: transaction.tagIds
          .where((candidate) => candidate != tagId)
          .toList(growable: false),
      modifiedAt: _clock.nowUtc,
    );

    final updateResult = await _updateTransaction(updated);

    if (updateResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    return Success(updated);
  }
}
