import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_offsets_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset_summary.dart';
import 'package:decimal/decimal.dart';

/// Derives gross, offset, and net amounts for one original transaction.
final class GetTransactionOffsetSummaryUseCase {
  /// Creates the summary use case.
  const GetTransactionOffsetSummaryUseCase({
    required GetTransactionByIdUseCase getTransactionById,
    required GetTransactionOffsetsUseCase getTransactionOffsets,
    required TransactionOffsetPolicy offsetPolicy,
  }) : _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _getTransactionOffsets = // ignore: prefer_initializing_formals
           getTransactionOffsets,
       _offsetPolicy = // ignore: prefer_initializing_formals
           offsetPolicy;

  final GetTransactionByIdUseCase _getTransactionById;
  final GetTransactionOffsetsUseCase _getTransactionOffsets;
  final TransactionOffsetPolicy _offsetPolicy;

  /// Returns the offset summary for [transactionId].
  Future<Result<TransactionOffsetSummary, TransactionFailure>> call(
    TransactionId transactionId,
  ) async {
    final originalResult = await _getTransactionById(transactionId);

    if (originalResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final original = originalResult.valueOrNull;

    if (original == null) {
      return TransactionNotFoundFailure(
        message:
            'Transaction ID was not found: '
            '${transactionId.value}',
      );
    }

    final originalValidation = _offsetPolicy.validateOriginal(original);

    if (originalValidation case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final offsetsResult = await _getTransactionOffsets(transactionId);

    if (offsetsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final offsets = offsetsResult.valueOrNull!;

    final acceptedOffsets = <Transaction>[];

    var refundAmount = Decimal.zero;
    var reimbursementAmount = Decimal.zero;
    var cashbackAmount = Decimal.zero;

    for (final offset in offsets) {
      final validation = _offsetPolicy.validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: acceptedOffsets,
      );

      if (validation case final Failure<TransactionFailure> failure) {
        return failure;
      }

      acceptedOffsets.add(offset);

      final amount = offset.ledgerEntries
          .singleWhere((entry) => entry.role == LedgerEntryRole.primary)
          .transactionAmount
          .amount;

      switch (offset.offset!.kind) {
        case TransactionOffsetKind.refund:
          refundAmount += amount;

        case TransactionOffsetKind.reimbursement:
          reimbursementAmount += amount;

        case TransactionOffsetKind.cashback:
          cashbackAmount += amount;
      }
    }

    final primaryAmount = original.ledgerEntries
        .singleWhere((entry) => entry.role == LedgerEntryRole.primary)
        .transactionAmount;

    return Success(
      TransactionOffsetSummary(
        transactionId: original.id,
        assetId: primaryAmount.assetId,
        grossAmount: primaryAmount.amount,
        refundAmount: refundAmount,
        reimbursementAmount: reimbursementAmount,
        cashbackAmount: cashbackAmount,
        offsets: offsets,
      ),
    );
  }
}
