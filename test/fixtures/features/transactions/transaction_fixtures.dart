import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';

/// Creates a valid expense transaction for tests.
Transaction transactionFixture({
  required String id,
  DateTime? deletedAt,
  DateTime? effectiveAt,
}) {
  final amount = AssetAmount(
    assetId: AssetId.fromString('asset-eur'),
    amount: Decimal.fromInt(10),
    direction: AssetAmountDirection.outgoing,
  );
  final createdAt = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt ?? createdAt,
    description: 'Test transaction',
    note: null,
    state: TransactionState.actual,
    deletedAt: deletedAt,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-eur'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: createdAt,
    modifiedAt: createdAt,
    entityVersion: 1,
  );
}

/// Creates a valid new expense transaction through [Transaction.create].
Transaction newTransactionFixture({DateTime? effectiveAt}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  final amount = AssetAmount(
    assetId: AssetId.fromString('asset-eur'),
    amount: Decimal.fromInt(10),
    direction: AssetAmountDirection.outgoing,
  );

  return Transaction.create(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt ?? createdAt,
    description: 'Test transaction',
    state: TransactionState.actual,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-eur'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
    clock: FixedClock(createdAt),
  );
}

/// Creates a valid expense transaction with one category allocation.
Transaction transactionWithCategoryAllocationFixture({
  required CategoryId categoryId,
  String id = 'transaction-with-allocation',
  DateTime? deletedAt,
}) {
  final amount = AssetAmount(
    assetId: AssetId.fromString('asset-eur'),
    amount: Decimal.fromInt(10),
    direction: AssetAmountDirection.outgoing,
  );
  final timestamp = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: timestamp,
    description: 'Allocated test transaction',
    note: null,
    state: TransactionState.actual,
    deletedAt: deletedAt,
    splits: [
      TransactionSplit(
        transactionAmount: amount,
        valuationAmount: amount,
        categoryId: categoryId,
      ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-eur'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
