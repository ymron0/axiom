@Tags(['integration'])
library;

import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/features/categories/category_fixtures.dart';

void main() {
  group('Transaction allocation hierarchy', () {
    final timestamp = DateTime.utc(2026, 1, 1);
    final assetId = AssetId.fromString('asset-eur');
    final expenseParent = categoryFixture(id: 'household', name: 'Household');
    final expenseChild = categoryFixture(
      id: 'groceries',
      name: 'Groceries',
      parentCategoryId: expenseParent.id.value,
    );
    final incomeParent = categoryFixture(
      id: 'earnings',
      name: 'Earnings',
      kind: CategoryKind.income,
    );
    final incomeChild = categoryFixture(
      id: 'salary',
      name: 'Salary',
      parentCategoryId: incomeParent.id.value,
      kind: CategoryKind.income,
    );

    late InMemoryTransactionRepositoryImpl transactionRepository;
    late CreateTransactionService service;

    setUp(() {
      final categoryRepository = InMemoryCategoryRepositoryImpl(
        initialCategories: [
          expenseParent,
          expenseChild,
          incomeParent,
          incomeChild,
        ],
      );
      transactionRepository = InMemoryTransactionRepositoryImpl(
        initialTransactions: const [],
      );
      service = CreateTransactionService(
        clock: FixedClock(timestamp),
        createTransaction: CreateTransactionUseCase(
          repository: transactionRepository,
        ),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: GetCategoryByIdUseCase(categoryRepository),
        ),
      );
    });

    CreateTransactionCommand command({
      required TransactionKind kind,
      required List<CategoryId> categoryIds,
    }) {
      final direction = kind == TransactionKind.income
          ? AssetAmountDirection.incoming
          : AssetAmountDirection.outgoing;
      final total = AssetAmount(
        assetId: assetId,
        amount: Decimal.fromInt(categoryIds.length * 10),
        direction: direction,
      );

      return CreateTransactionCommand(
        kind: kind,
        merchantId: MerchantId.self,
        effectiveAt: timestamp,
        description: 'Hierarchy allocation',
        state: TransactionState.actual,
        splits: [
          for (final categoryId in categoryIds)
            TransactionSplit(
              transactionAmount: AssetAmount(
                assetId: assetId,
                amount: Decimal.fromInt(10),
                direction: direction,
              ),
              valuationAmount: AssetAmount(
                assetId: assetId,
                amount: Decimal.fromInt(10),
                direction: direction,
              ),
              categoryId: categoryId,
            ),
        ],
        ledgerEntries: [
          LedgerEntry(
            accountId: AccountId.fromString('account-eur'),
            transactionAmount: total,
            accountAmount: total,
            valuationAmount: total,
            role: LedgerEntryRole.primary,
          ),
        ],
      );
    }

    test('persists expense allocations to parent and child categories', () async {
      // Given
      final createCommand = command(
        kind: TransactionKind.expense,
        categoryIds: [expenseParent.id, expenseChild.id],
      );

      // When
      final result = await service(createCommand);

      // Then
      final transaction = result.valueOrNull!;
      expect(
        transaction.splits.map((split) => split.categoryId),
        [expenseParent.id, expenseChild.id],
      );
      final persisted = await transactionRepository.getById(transaction.id);
      expect(persisted.valueOrNull, same(transaction));
    });

    test('persists income allocations to parent and child categories', () async {
      // Given
      final createCommand = command(
        kind: TransactionKind.income,
        categoryIds: [incomeParent.id, incomeChild.id],
      );

      // When
      final result = await service(createCommand);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.kind, TransactionKind.income);
      expect(result.valueOrNull!.splits, hasLength(2));
    });

    test('rejects a missing category without persisting', () async {
      // Given
      final createCommand = command(
        kind: TransactionKind.expense,
        categoryIds: [CategoryId.fromString('missing')],
      );

      // When
      final result = await service(createCommand);

      // Then
      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());
      expect((await transactionRepository.getAll()).valueOrNull, isEmpty);
    });

    test('rejects an incompatible category kind without persisting', () async {
      // Given
      final createCommand = command(
        kind: TransactionKind.expense,
        categoryIds: [incomeChild.id],
      );

      // When
      final result = await service(createCommand);

      // Then
      expect(
        result.failureOrNull,
        isA<AllocationCategoryKindMismatchFailure>(),
      );
      expect((await transactionRepository.getAll()).valueOrNull, isEmpty);
    });
  });
}
