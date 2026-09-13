import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction allocation dimensions', () {
    final assetId = AssetId.fromString('asset-eur');
    final transactionAmount = AssetAmount.outgoing(
      assetId: assetId,
      amount: Decimal.fromInt(10),
    );
    final valuationAmount = AssetAmount.outgoing(
      assetId: assetId,
      amount: Decimal.fromInt(10),
    );
    final ledgerEntry = LedgerEntry(
      accountId: AccountId.fromString('account-1'),
      transactionAmount: transactionAmount,
      accountAmount: transactionAmount,
      valuationAmount: valuationAmount,
      role: LedgerEntryRole.primary,
    );
    final firstCategoryId = CategoryId.fromString('category-1');
    final secondCategoryId = CategoryId.fromString('category-2');
    final jarId = JarId.fromString('jar-1');

    Transaction createTransaction(TransactionSplit split) {
      return Transaction(
        id: TransactionId.fromString('transaction-1'),
        kind: TransactionKind.expense,
        merchantId: MerchantId.self,
        effectiveAt: DateTime.utc(2026, 1, 2),
        description: 'Groceries',
        note: 'Weekly shop',
        state: TransactionState.actual,
        splits: [split],
        ledgerEntries: [ledgerEntry],
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        entityVersion: 1,
      );
    }

    test('accepts category and jar allocations independently', () {
      // Given / When
      final categoryTransaction = createTransaction(
        TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: valuationAmount,
          categoryId: firstCategoryId,
        ),
      );
      final jarTransaction = createTransaction(
        TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: valuationAmount,
          jarId: jarId,
        ),
      );

      // Then
      expect(categoryTransaction.splits.single.categoryId, firstCategoryId);
      expect(categoryTransaction.splits.single.jarId, isNull);
      expect(jarTransaction.splits.single.categoryId, isNull);
      expect(jarTransaction.splits.single.jarId, jarId);
    });

    test('category changes preserve unrelated allocation data', () {
      // Given / When
      final transactions = [firstCategoryId, secondCategoryId, null].map(
        (categoryId) => createTransaction(
          TransactionSplit(
            transactionAmount: transactionAmount,
            valuationAmount: valuationAmount,
            categoryId: categoryId,
            jarId: jarId,
          ),
        ),
      );

      // Then
      expect(
        transactions.map((transaction) => transaction.splits.single.jarId),
        everyElement(jarId),
      );
      expect(
        transactions.map(
          (transaction) => transaction.splits.single.transactionAmount,
        ),
        everyElement(transactionAmount),
      );
      expect(
        transactions.map(
          (transaction) => transaction.splits.single.valuationAmount,
        ),
        everyElement(valuationAmount),
      );
      expect(
        transactions.map((transaction) => transaction.ledgerEntries.single),
        everyElement(ledgerEntry),
      );
    });

    test('allocation validation does not depend on the target dimension', () {
      // Given
      final incomingValuationAmount = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.fromInt(10),
      );

      Matcher rejectsMismatchedDirection() {
        return throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Valuation amount must have the same direction as the transaction '
                'amount.',
          ),
        );
      }

      // When / Then
      expect(
        () => TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: incomingValuationAmount,
          categoryId: firstCategoryId,
        ),
        rejectsMismatchedDirection(),
      );
      expect(
        () => TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: incomingValuationAmount,
          jarId: jarId,
        ),
        rejectsMismatchedDirection(),
      );
      expect(
        () => TransactionSplit(
          transactionAmount: transactionAmount,
          valuationAmount: incomingValuationAmount,
          categoryId: firstCategoryId,
          jarId: jarId,
        ),
        rejectsMismatchedDirection(),
      );
    });
  });
}
