import 'package:axiom/src/application/di/services/build_transaction_ledger_entry_service_provider.dart';
import 'package:axiom/src/application/di/services/create_transaction_offset_service_provider.dart';
import 'package:axiom/src/application/di/services/create_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/delete_transaction_occurrence_service_provider.dart';
import 'package:axiom/src/application/di/services/restore_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/update_transaction_service_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_offset_command.dart';
import 'package:axiom/src/features/transactions/di/delete_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_occurrence_deletion_mode.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks creation of a transaction.
final createTransactionMutation = Mutation<Transaction>(
  label: 'createTransaction',
);

/// Tracks update of one transaction.
///
/// Use the transaction ID as mutation key.
final updateTransactionMutation = Mutation<Transaction>(
  label: 'updateTransaction',
);

/// Tracks standalone physical deletion.
///
/// Use the transaction ID as mutation key.
final deleteTransactionMutation = Mutation<Transaction>(
  label: 'deleteTransaction',
);

/// Tracks occurrence-aware deletion.
///
/// Use the transaction ID as mutation key.
final deleteTransactionOccurrenceMutation = Mutation<void>(
  label: 'deleteTransactionOccurrence',
);

/// Tracks restoration of a caller-retained deleted transaction snapshot.
final restoreTransactionMutation = Mutation<void>(label: 'restoreTransaction');

/// Tracks creation of a transaction offset/refund.
final refundTransactionMutation = Mutation<Transaction>(
  label: 'refundTransaction',
);

/// Exception wrapper used only to bridge typed [Result] failures into the
/// Mutation API's error state.
///
/// The original [BaseFailure] remains available to the presentation failure
/// mapper.
final class TransactionMutationFailure implements Exception {
  final BaseFailure failure;

  /// Creates a mutation failure wrapper.
  const TransactionMutationFailure(this.failure);

  @override
  String toString() => 'TransactionMutationFailure(${failure.type})';
}

/// One primary financial movement entered by the user.
final class TransactionEntryRequest {
  final AccountId accountId;
  final AssetId assetId;
  final Decimal amount;
  final AssetAmountDirection direction;

  /// Creates one requested primary ledger movement.
  const TransactionEntryRequest({
    required this.accountId,
    required this.assetId,
    required this.amount,
    required this.direction,
  });
}

/// Optional transaction fee.
final class TransactionFeeRequest {
  final AccountId accountId;
  final AssetId? assetId;
  final Decimal? amount;
  final Decimal? percentage;

  const TransactionFeeRequest._({
    required this.accountId,
    this.assetId,
    this.amount,
    this.percentage,
  });

  /// Fee expressed directly in an asset.
  factory TransactionFeeRequest.assetAmount({
    required AccountId accountId,
    required AssetId assetId,
    required Decimal amount,
  }) {
    return TransactionFeeRequest._(
      accountId: accountId,
      assetId: assetId,
      amount: amount,
    );
  }

  /// Fee expressed as a percentage of the first primary entry.
  factory TransactionFeeRequest.percentage({
    required AccountId accountId,
    required Decimal percentage,
  }) {
    return TransactionFeeRequest._(
      accountId: accountId,
      percentage: percentage,
    );
  }

  /// Whether this is percentage based.
  bool get isPercentage => percentage != null;
}

/// Financial portion of a transaction editor submission.
final class TransactionFinancialRequest {
  final TransactionKind kind;
  final List<TransactionEntryRequest> entries;
  final CategoryId? categoryId;
  final JarId? jarId;
  final TransactionFeeRequest? fee;

  /// Creates financial submission data.
  TransactionFinancialRequest({
    required this.kind,
    required List<TransactionEntryRequest> entries,
    this.categoryId,
    this.jarId,
    this.fee,
  }) : entries = List.unmodifiable(entries) {
    if (this.entries.isEmpty) {
      throw ArgumentError('At least one transaction entry is required.');
    }
  }
}

/// Complete create-transaction request from presentation.
final class TransactionCreateRequest {
  final TransactionFinancialRequest financial;
  final MerchantId merchantId;
  final DateTime effectiveAt;
  final String? description;
  final String? note;
  final TransactionState state;
  final List<TagId> tagIds;

  /// Creates a presentation submission.
  TransactionCreateRequest({
    required this.financial,
    required this.merchantId,
    required this.effectiveAt,
    this.description,
    this.note,
    required this.state,
    List<TagId> tagIds = const [],
  }) : tagIds = List.unmodifiable(tagIds);
}

/// Complete edit request.
///
/// [financial] may be omitted for legacy/complex transactions that the compact
/// editor cannot safely reconstruct. In that case existing ledger entries and
/// allocations are retained unchanged.
final class TransactionUpdateRequest {
  final Transaction original;
  final TransactionFinancialRequest? financial;
  final MerchantId merchantId;
  final DateTime effectiveAt;
  final String? description;
  final String? note;
  final TransactionState state;
  final List<TagId> tagIds;

  /// Creates an update submission.
  TransactionUpdateRequest({
    required this.original,
    this.financial,
    required this.merchantId,
    required this.effectiveAt,
    this.description,
    this.note,
    required this.state,
    required List<TagId> tagIds,
  }) : tagIds = List.unmodifiable(tagIds);
}

/// Presentation input for a full or partial offset.
final class TransactionRefundRequest {
  final Transaction original;
  final TransactionOffsetKind offsetKind;
  final MerchantId merchantId;
  final DateTime effectiveAt;
  final Decimal amount;
  final String? description;
  final String? note;
  final List<TagId> tagIds;

  /// Creates a refund/offset request.
  TransactionRefundRequest({
    required this.original,
    required this.offsetKind,
    required this.merchantId,
    required this.effectiveAt,
    required this.amount,
    this.description,
    this.note,
    List<TagId> tagIds = const [],
  }) : tagIds = List.unmodifiable(tagIds);
}

/// Runs transaction creation.
Future<Transaction> runCreateTransactionMutation(
  WidgetRef ref,
  TransactionCreateRequest request,
) {
  return createTransactionMutation.run(ref, (transaction) async {
    final financial = await _assembleFinancials(
      transaction,
      request.financial,
      effectiveAt: request.effectiveAt,
    );

    final command = CreateTransactionCommand(
      kind: request.financial.kind,
      merchantId: request.merchantId,
      effectiveAt: request.effectiveAt,
      description: request.description,
      note: request.note,
      state: request.state,
      tagIds: request.tagIds,
      splits: financial.splits,
      ledgerEntries: financial.ledgerEntries,
    );

    final result = await transaction
        .get(createTransactionServiceProvider)
        .call(command);

    return _unwrap(result);
  });
}

/// Runs transaction update.
Future<Transaction> runUpdateTransactionMutation(
  WidgetRef ref,
  TransactionUpdateRequest request,
) {
  final mutation = updateTransactionMutation(request.original.id.value);

  return mutation.run(ref, (transaction) async {
    final financial = request.financial == null
        ? null
        : await _assembleFinancials(
            transaction,
            request.financial!,
            effectiveAt: request.effectiveAt,
          );

    final now = transaction.get(clockProvider).nowUtc;

    final updated = request.original.copyWith(
      merchantId: request.merchantId,
      effectiveAt: request.effectiveAt,
      description: request.description,
      note: request.note,
      state: request.state,
      tagIds: request.tagIds,
      splits: financial?.splits ?? request.original.splits,
      ledgerEntries: financial?.ledgerEntries ?? request.original.ledgerEntries,
      modifiedAt: now,
    );

    final result = await transaction
        .get(updateTransactionServiceProvider)
        .call(updated);

    _unwrap(result);

    return updated;
  });
}

/// Deletes a standalone transaction and returns its caller-owned restore
/// snapshot.
Future<Transaction> runDeleteTransactionMutation(
  WidgetRef ref,
  Transaction transaction,
) {
  final mutation = deleteTransactionMutation(transaction.id.value);

  return mutation.run(ref, (tsx) async {
    final result = await tsx
        .get(deleteTransactionUseCaseProvider)
        .call(transaction.id, tsx.get(clockProvider).nowUtc);

    return _unwrap(result);
  });
}

/// Deletes a recurrence occurrence through the series-aware workflow.
Future<void> runDeleteTransactionOccurrenceMutation(
  WidgetRef ref, {
  required Transaction transaction,
  required TransactionOccurrenceDeletionMode mode,
}) {
  final mutation = deleteTransactionOccurrenceMutation(transaction.id.value);

  return mutation.run(ref, (tsx) async {
    final result = await tsx
        .get(deleteTransactionOccurrenceServiceProvider)
        .call(id: transaction.id, mode: mode);

    _unwrap(result);
  });
}

/// Restores a caller-retained standalone deletion snapshot.
Future<void> runRestoreTransactionMutation(
  WidgetRef ref,
  Transaction deletedSnapshot,
) {
  final mutation = restoreTransactionMutation(deletedSnapshot.id.value);

  return mutation.run(ref, (tsx) async {
    final result = await tsx
        .get(restoreTransactionServiceProvider)
        .call(deletedSnapshot);

    _unwrap(result);
  });
}

/// Creates a full or partial refund/reimbursement/cashback transaction.
Future<Transaction> runRefundTransactionMutation(
  WidgetRef ref,
  TransactionRefundRequest request,
) {
  final mutation = refundTransactionMutation(request.original.id.value);

  return mutation.run(ref, (tsx) async {
    final originalPrimaryEntries = request.original.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList(growable: false);

    if (originalPrimaryEntries.length != 1) {
      throw StateError(
        'Transaction offsets require an original transaction with one '
        'primary entry.',
      );
    }

    final originalPrimary = originalPrimaryEntries.single;

    final direction = originalPrimary.transactionAmount.isOutgoing
        ? AssetAmountDirection.incoming
        : AssetAmountDirection.outgoing;

    final amount = AssetAmount(
      assetId: originalPrimary.transactionAmount.assetId,
      amount: request.amount,
      direction: direction,
    );

    final ledgerResult = await tsx
        .get(buildTransactionLedgerEntryServiceProvider)
        .call(
          accountId: originalPrimary.accountId,
          transactionAmount: amount,
          effectiveAt: request.effectiveAt,
        );

    final ledgerEntry = _unwrap(ledgerResult);

    final command = CreateTransactionOffsetCommand(
      originalTransactionId: request.original.id,
      offsetKind: request.offsetKind,
      merchantId: request.merchantId,
      effectiveAt: request.effectiveAt,
      description: request.description,
      note: request.note,
      tagIds: request.tagIds,
      splits: const [],
      ledgerEntries: [ledgerEntry],
    );

    final result = await tsx
        .get(createTransactionOffsetServiceProvider)
        .call(command);

    return _unwrap(result);
  });
}

Future<_TransactionFinancials> _assembleFinancials(
  MutationTransaction transaction,
  TransactionFinancialRequest request, {
  required DateTime effectiveAt,
}) async {
  final builder = transaction.get(buildTransactionLedgerEntryServiceProvider);

  final ledgerEntries = <LedgerEntry>[];

  for (final entry in request.entries) {
    final transactionAmount = AssetAmount(
      assetId: entry.assetId,
      amount: entry.amount,
      direction: entry.direction,
    );

    final result = await builder(
      accountId: entry.accountId,
      transactionAmount: transactionAmount,
      effectiveAt: effectiveAt,
    );

    ledgerEntries.add(_unwrap(result));
  }

  final fee = request.fee;

  if (fee != null) {
    final AssetAmount feeAmount;
    final Decimal? feePercentage;

    if (fee.isPercentage) {
      final base = request.entries.first;
      final percentage = fee.percentage!;

      final calculatedAmount =
          ((base.amount * percentage) / Decimal.fromInt(100)).toDecimal(
            scaleOnInfinitePrecision: 18,
          );

      feeAmount = AssetAmount.outgoing(
        assetId: base.assetId,
        amount: calculatedAmount,
      );

      feePercentage = percentage;
    } else {
      feeAmount = AssetAmount.outgoing(
        assetId: fee.assetId!,
        amount: fee.amount!,
      );

      feePercentage = null;
    }

    final feeResult = await builder(
      accountId: fee.accountId,
      transactionAmount: feeAmount,
      effectiveAt: effectiveAt,
      role: LedgerEntryRole.fee,
      feePercentage: feePercentage,
    );

    ledgerEntries.add(_unwrap(feeResult));
  }

  final splits = <TransactionSplit>[];

  if (request.categoryId != null || request.jarId != null) {
    if (!request.kind.supportsSplits) {
      throw ArgumentError(
        'Transaction kind ${request.kind.name} does not support allocations.',
      );
    }

    final primaryEntries = ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList(growable: false);

    if (primaryEntries.length != 1) {
      throw StateError(
        'A full transaction allocation requires one primary ledger entry.',
      );
    }

    final primary = primaryEntries.single;

    splits.add(
      TransactionSplit(
        transactionAmount: primary.transactionAmount,
        valuationAmount: primary.valuationAmount,
        categoryId: request.categoryId,
        jarId: request.jarId,
      ),
    );
  }

  return _TransactionFinancials(ledgerEntries: ledgerEntries, splits: splits);
}

T _unwrap<T, F extends BaseFailure>(Result<T, F> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) {
      throw TransactionMutationFailure(failure.failureOrNull);
    },
  );
}

final class _TransactionFinancials {
  final List<LedgerEntry> ledgerEntries;
  final List<TransactionSplit> splits;

  _TransactionFinancials({
    required List<LedgerEntry> ledgerEntries,
    required List<TransactionSplit> splits,
  }) : ledgerEntries = List.unmodifiable(ledgerEntries),
       splits = List.unmodifiable(splits);
}
