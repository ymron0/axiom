import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
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

final AssetId transactionOffsetFixtureAssetId = AssetId.fromString('asset-chf');

final AccountId transactionOffsetFixtureAccountId = AccountId.fromString(
  'account-chf',
);

/// Creates a valid original transaction.
Transaction offsetOriginalTransactionFixture({
  String id = 'original',
  Decimal? amount,
  DateTime? effectiveAt,
  TransactionState state = TransactionState.actual,
  TransactionKind kind = TransactionKind.expense,
  CategoryId? categoryId,
  List<({CategoryId categoryId, Decimal amount})>? allocations,
}) {
  final resolvedAmount = amount ?? Decimal.fromInt(100);
  final timestamp = DateTime.utc(2026, 1, 1);
  final direction = kind == TransactionKind.income
      ? AssetAmountDirection.incoming
      : AssetAmountDirection.outgoing;
  final resolvedAllocations = allocations ??
      (categoryId == null
          ? const <({CategoryId categoryId, Decimal amount})>[]
          : [(categoryId: categoryId, amount: resolvedAmount)]);

  final assetAmount = AssetAmount(
    assetId: transactionOffsetFixtureAssetId,
    amount: resolvedAmount,
    direction: direction,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: kind,
    merchantId: MerchantId.fromString('merchant-original'),
    effectiveAt: effectiveAt ?? timestamp,
    description: 'Original expense',
    note: null,
    state: state,
    offset: null,
    deletedAt: null,
    splits: [
      for (final allocation in resolvedAllocations)
        TransactionSplit(
          transactionAmount: AssetAmount(
            assetId: transactionOffsetFixtureAssetId,
            amount: allocation.amount,
            direction: direction,
          ),
          valuationAmount: AssetAmount(
            assetId: transactionOffsetFixtureAssetId,
            amount: allocation.amount,
            direction: direction,
          ),
          categoryId: allocation.categoryId,
        ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: transactionOffsetFixtureAccountId,
        transactionAmount: assetAmount,
        accountAmount: assetAmount,
        valuationAmount: assetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}

/// Creates a valid offset of an expense transaction.
Transaction offsetTransactionFixture({
  String id = 'offset',
  String originalId = 'original',
  Decimal? amount,
  TransactionOffsetKind offsetKind = TransactionOffsetKind.reimbursement,
  DateTime? effectiveAt,
  CategoryId? categoryId,
  AssetId? assetId,
  TransactionState state = TransactionState.actual,
  TransactionKind kind = TransactionKind.income,
}) {
  final resolvedAmount = amount ?? Decimal.fromInt(50);
  final timestamp = DateTime.utc(2026, 1, 2);
  final resolvedAssetId = assetId ?? transactionOffsetFixtureAssetId;

  final assetAmount = AssetAmount(
    assetId: resolvedAssetId,
    amount: resolvedAmount,
    direction: kind == TransactionKind.expense
        ? AssetAmountDirection.outgoing
        : AssetAmountDirection.incoming,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: kind,
    merchantId: MerchantId.fromString('merchant-offset'),
    effectiveAt: effectiveAt ?? timestamp,
    description: 'Offset',
    note: null,
    state: state,
    offset: TransactionOffset(
      originalTransactionId: TransactionId.fromString(originalId),
      kind: offsetKind,
    ),
    deletedAt: null,
    splits: categoryId == null
        ? const []
        : [
            TransactionSplit(
              transactionAmount: assetAmount,
              valuationAmount: assetAmount,
              categoryId: categoryId,
            ),
          ],
    ledgerEntries: [
      LedgerEntry(
        accountId: transactionOffsetFixtureAccountId,
        transactionAmount: assetAmount,
        accountAmount: assetAmount,
        valuationAmount: assetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}

/// Creates a reimbursement command for an expense transaction.
CreateTransactionOffsetCommand transactionOffsetCommandFixture({
  TransactionId? originalTransactionId,
  Decimal? amount,
  TransactionOffsetKind offsetKind = TransactionOffsetKind.reimbursement,
  CategoryId? categoryId,
  TransactionKind transactionKind = TransactionKind.income,
}) {
  final resolvedAmount = amount ?? Decimal.fromInt(50);

  final assetAmount = AssetAmount(
    assetId: transactionOffsetFixtureAssetId,
    amount: resolvedAmount,
    direction: transactionKind == TransactionKind.expense
        ? AssetAmountDirection.outgoing
        : AssetAmountDirection.incoming,
  );

  return CreateTransactionOffsetCommand(
    originalTransactionId:
        originalTransactionId ?? TransactionId.fromString('original'),
    offsetKind: offsetKind,
    merchantId: MerchantId.fromString('partner'),
    effectiveAt: DateTime.utc(2026, 1, 2),
    description: 'Partner reimbursement',
    splits: categoryId == null
        ? const []
        : [
            TransactionSplit(
              transactionAmount: assetAmount,
              valuationAmount: assetAmount,
              categoryId: categoryId,
            ),
          ],
    ledgerEntries: [
      LedgerEntry(
        accountId: transactionOffsetFixtureAccountId,
        transactionAmount: assetAmount,
        accountAmount: assetAmount,
        valuationAmount: assetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}
