import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_id_use_case.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';

/// Assigns reusable tag metadata to an existing transaction.
///
/// Assignment is idempotent. Assigning a tag already present on the transaction
/// succeeds without writing another transaction snapshot.
///
/// New assignments require the tag to exist and remain active.
final class AssignTagToTransactionService {
  final Clock _clock;
  final GetTransactionByIdUseCase _getTransactionById;
  final GetTagByIdUseCase _getTagById;
  final UpdateTransactionUseCase _updateTransaction;

  /// Creates a tag-assignment workflow.
  const AssignTagToTransactionService({
    required Clock clock,
    required GetTransactionByIdUseCase getTransactionById,
    required GetTagByIdUseCase getTagById,
    required UpdateTransactionUseCase updateTransaction,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _getTagById = getTagById, // ignore: prefer_initializing_formals
       _updateTransaction = // ignore: prefer_initializing_formals
           updateTransaction;

  /// Assigns [tagId] to [transactionId].
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

    if (transaction.tagIds.contains(tagId)) {
      return Success(transaction);
    }

    final tagResult = await _getTagById(tagId);

    if (tagResult case final Failure<TagFailure> failure) {
      return failure;
    }

    final tag = tagResult.valueOrNull;

    if (tag == null) {
      return TagNotFoundFailure(
        message: 'Tag ID was not found: ${tagId.value}',
      );
    }

    if (tag.isArchived) {
      return TagNotAssignableFailure(
        message:
            'Archived tag cannot be newly assigned to a transaction: '
            '${tag.id.value}',
      );
    }

    final updated = transaction.copyWith(
      tagIds: <TagId>[...transaction.tagIds, tagId],
      modifiedAt: _clock.nowUtc,
    );

    final updateResult = await _updateTransaction(updated);

    if (updateResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    return Success(updated);
  }
}
