@Tags(['integration'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/restore_category_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/features/categories/category_fixtures.dart';

void main() {
  group('Deleted transaction allocation resolution', () {
    test('preserves the category reference through deletion and restoration', () async {
      // Given
      final category = categoryFixture(id: 'groceries', name: 'Groceries');
      final amount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-eur'),
        amount: Decimal.fromInt(10),
      );
      final transaction = Transaction(
        id: TransactionId.fromString('transaction-1'),
        kind: TransactionKind.expense,
        merchantId: MerchantId.self,
        effectiveAt: DateTime.utc(2026, 1, 2),
        description: 'Groceries',
        state: TransactionState.actual,
        splits: [
          TransactionSplit(
            transactionAmount: amount,
            valuationAmount: amount,
            categoryId: category.id,
          ),
        ],
        ledgerEntries: [
          LedgerEntry(
            accountId: AccountId.fromString('account-1'),
            transactionAmount: amount,
            accountAmount: amount,
            valuationAmount: amount,
            role: LedgerEntryRole.primary,
          ),
        ],
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        entityVersion: 1,
      );
      final categoryRepository = InMemoryCategoryRepositoryImpl(
        initialCategories: [category],
      );
      final transactionRepository = InMemoryTransactionRepositoryImpl(
        initialTransactions: [transaction],
      );
      final deleteCategory = DeleteCategoryUseCase(categoryRepository);
      final restoreCategory = RestoreCategoryUseCase(categoryRepository);
      final getCategoryById = GetCategoryByIdUseCase(categoryRepository);

      // When
      final deleted = (await deleteCategory(category.id)).valueOrNull!;

      // Then
      expect((await getCategoryById(category.id)).valueOrNull, isNull);
      final persistedWhileDeleted =
          (await transactionRepository.getById(transaction.id)).valueOrNull!;
      expect(persistedWhileDeleted, same(transaction));
      expect(persistedWhileDeleted.splits.single.categoryId, category.id);

      // When
      final restoreResult = await restoreCategory(deleted);

      // Then
      expect(restoreResult.isSuccess, isTrue);
      expect((await getCategoryById(category.id)).valueOrNull?.id, category.id);
      final persistedAfterRestore =
          (await transactionRepository.getById(transaction.id)).valueOrNull!;
      expect(persistedAfterRestore, same(transaction));
      expect(persistedAfterRestore.splits.single.categoryId, category.id);
    });
  });
}
