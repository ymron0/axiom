import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_offset_command.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';

/// Default transaction asset used by refund fixtures.
final AssetId refundAssetId = AssetId.fromString('asset-chf');

/// Default account used by the original transaction.
final AccountId refundOriginalAccountId = AccountId.fromString(
  'account-original-chf',
);

/// Default account receiving the refund.
final AccountId refundReceivingAccountId = AccountId.fromString(
  'account-refund-chf',
);

/// Default merchant responsible for the original purchase and refund.
final MerchantId refundMerchantId = MerchantId.fromString(
  'merchant-refund-store',
);

/// Creates a valid original expense that may later receive refunds.
///
/// The returned transaction is an actual standalone expense with no offset
/// relationship.
///
/// [amount] represents the original purchase amount in the transaction asset.
///
/// When [categoryId] or [jarId] is supplied, the complete original amount is
/// allocated to that target combination.
Transaction refundableExpenseTransactionFixture({
  String id = 'refund-original',
  Decimal? amount,
  AssetId? assetId,
  AccountId? accountId,
  MerchantId? merchantId,
  DateTime? effectiveAt,
  TransactionState state = TransactionState.actual,
  CategoryId? categoryId,
  JarId? jarId,
  String? description = 'Original purchase',
  String? note,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final resolvedAmount = amount ?? Decimal.fromInt(100);
  final resolvedAssetId = assetId ?? refundAssetId;
  final resolvedAccountId = accountId ?? refundOriginalAccountId;
  final resolvedMerchantId = merchantId ?? refundMerchantId;
  final createdAt = DateTime.utc(2026, 1, 1);

  final transactionAmount = AssetAmount(
    assetId: resolvedAssetId,
    amount: resolvedAmount,
    direction: AssetAmountDirection.outgoing,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.expense,
    merchantId: resolvedMerchantId,
    effectiveAt: effectiveAt ?? createdAt,
    description: description,
    note: note,
    state: state,
    offset: null,
    deletedAt: deletedAt,
    splits: _splits(
      amount: transactionAmount,
      categoryId: categoryId,
      jarId: jarId,
    ),
    ledgerEntries: [
      LedgerEntry(
        accountId: resolvedAccountId,
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: transactionAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}

/// Creates a valid refund transaction linked to an original expense.
///
/// A refund remains an ordinary income transaction. Its economic relationship
/// to the original expense is represented by [Transaction.offset].
///
/// [amount] is the amount returned by the merchant.
///
/// When the original transaction is allocated, matching [categoryId] and/or
/// [jarId] values should be supplied so the refund reduces the same allocation
/// in category and jar reporting.
Transaction refundTransactionFixture({
  String id = 'refund-offset',
  String originalTransactionId = 'refund-original',
  Decimal? amount,
  AssetId? assetId,
  AccountId? accountId,
  MerchantId? merchantId,
  DateTime? effectiveAt,
  TransactionState state = TransactionState.actual,
  CategoryId? categoryId,
  JarId? jarId,
  String? description = 'Merchant refund',
  String? note,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final resolvedAmount = amount ?? Decimal.fromInt(50);
  final resolvedAssetId = assetId ?? refundAssetId;
  final resolvedAccountId = accountId ?? refundReceivingAccountId;
  final resolvedMerchantId = merchantId ?? refundMerchantId;
  final createdAt = DateTime.utc(2026, 1, 2);

  final transactionAmount = AssetAmount(
    assetId: resolvedAssetId,
    amount: resolvedAmount,
    direction: AssetAmountDirection.incoming,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.income,
    merchantId: resolvedMerchantId,
    effectiveAt: effectiveAt ?? createdAt,
    description: description,
    note: note,
    state: state,
    offset: TransactionOffset(
      originalTransactionId: TransactionId.fromString(originalTransactionId),
      kind: TransactionOffsetKind.refund,
    ),
    deletedAt: deletedAt,
    splits: _splits(
      amount: transactionAmount,
      categoryId: categoryId,
      jarId: jarId,
    ),
    ledgerEntries: [
      LedgerEntry(
        accountId: resolvedAccountId,
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: transactionAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}

/// Creates a command for creating a merchant refund.
///
/// Transaction kind and lifecycle state are deliberately absent because
/// [CreateTransactionOffsetService] derives them from the original
/// transaction.
///
/// The command identifies the returned value as a merchant refund through
/// [TransactionOffsetKind.refund].
CreateTransactionOffsetCommand createRefundOffsetCommandFixture({
  TransactionId? originalTransactionId,
  Decimal? amount,
  AssetId? assetId,
  AccountId? accountId,
  MerchantId? merchantId,
  DateTime? effectiveAt,
  CategoryId? categoryId,
  JarId? jarId,
  String? description = 'Merchant refund',
  String? note,
}) {
  final resolvedAmount = amount ?? Decimal.fromInt(50);
  final resolvedAssetId = assetId ?? refundAssetId;
  final resolvedAccountId = accountId ?? refundReceivingAccountId;

  final transactionAmount = AssetAmount(
    assetId: resolvedAssetId,
    amount: resolvedAmount,
    direction: AssetAmountDirection.incoming,
  );

  return CreateTransactionOffsetCommand(
    originalTransactionId:
        originalTransactionId ?? TransactionId.fromString('refund-original'),
    offsetKind: TransactionOffsetKind.refund,
    merchantId: merchantId ?? refundMerchantId,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 2),
    description: description,
    note: note,
    splits: _splits(
      amount: transactionAmount,
      categoryId: categoryId,
      jarId: jarId,
    ),
    ledgerEntries: [
      LedgerEntry(
        accountId: resolvedAccountId,
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: transactionAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}

/// Creates a valid full refund matching [original].
///
/// The returned transaction reverses the original primary transaction amount,
/// preserves its transaction asset, merchant, and allocation targets, and may
/// affect a different account.
Transaction fullRefundForFixture(
  Transaction original, {
  String id = 'full-refund',
  AccountId? accountId,
  DateTime? effectiveAt,
}) {
  final primaryEntry = original.ledgerEntries.singleWhere(
    (entry) => entry.role == LedgerEntryRole.primary,
  );

  final transactionAmount = AssetAmount.incoming(
    assetId: primaryEntry.transactionAmount.assetId,
    amount: primaryEntry.transactionAmount.amount,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.income,
    merchantId: original.merchantId,
    effectiveAt:
        effectiveAt ?? original.effectiveAt.add(const Duration(days: 1)),
    description: 'Full merchant refund',
    note: null,
    state: TransactionState.actual,
    offset: TransactionOffset(
      originalTransactionId: original.id,
      kind: TransactionOffsetKind.refund,
    ),
    deletedAt: null,
    splits: [
      for (final split in original.splits)
        TransactionSplit(
          transactionAmount: AssetAmount.incoming(
            assetId: split.transactionAmount.assetId,
            amount: split.transactionAmount.amount,
          ),
          valuationAmount: AssetAmount.incoming(
            assetId: split.valuationAmount.assetId,
            amount: split.valuationAmount.amount,
          ),
          categoryId: split.categoryId,
          jarId: split.jarId,
        ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: accountId ?? refundReceivingAccountId,
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: AssetAmount.incoming(
          assetId: primaryEntry.valuationAmount.assetId,
          amount: primaryEntry.valuationAmount.amount,
        ),
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 2),
    modifiedAt: DateTime.utc(2026, 1, 2),
    entityVersion: 1,
  );
}

/// Creates one complete allocation split when at least one target is supplied.
///
/// Returns an empty list when the transaction has no category or jar
/// allocation.
List<TransactionSplit> _splits({
  required AssetAmount amount,
  required CategoryId? categoryId,
  required JarId? jarId,
}) {
  if (categoryId == null && jarId == null) {
    return const [];
  }

  return [
    TransactionSplit(
      transactionAmount: amount,
      valuationAmount: amount,
      categoryId: categoryId,
      jarId: jarId,
    ),
  ];
}
