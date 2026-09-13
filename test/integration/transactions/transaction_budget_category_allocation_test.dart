import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
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
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/features/categories/category_fixtures.dart';

void main() {
  group('Transaction jar and category allocation workflow', () {
    final timestamp = DateTime.utc(2026, 1, 1);
    final assetId = AssetId.fromString('asset-eur');
    final expenseCategory = categoryFixture(id: 'groceries');
    final incomeCategory = categoryFixture(
      id: 'salary',
      kind: CategoryKind.income,
    );
    final jarId = JarId.fromString('monthly-budget');

    late InMemoryTransactionRepositoryImpl transactionRepository;
    late CreateTransactionService service;

    setUp(() {
      transactionRepository = InMemoryTransactionRepositoryImpl(
        initialTransactions: const [],
      );
      service = CreateTransactionService(
        clock: FixedClock(timestamp),
        createTransaction: CreateTransactionUseCase(
          repository: transactionRepository,
        ),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: GetCategoryByIdUseCase(
            InMemoryCategoryRepositoryImpl(
              initialCategories: [expenseCategory, incomeCategory],
            ),
          ),
        ),
      );
    });

    CreateTransactionCommand command({
      required TransactionKind kind,
      CategoryId? categoryId,
      JarId? allocationJarId,
    }) {
      final direction = kind == TransactionKind.income
          ? AssetAmountDirection.incoming
          : AssetAmountDirection.outgoing;
      final amount = AssetAmount(
        assetId: assetId,
        amount: Decimal.fromInt(10),
        direction: direction,
      );

      return CreateTransactionCommand(
        kind: kind,
        merchantId: MerchantId.self,
        effectiveAt: timestamp,
        description: 'Allocated transaction',
        state: TransactionState.actual,
        splits: [
          TransactionSplit(
            transactionAmount: amount,
            valuationAmount: amount,
            categoryId: categoryId,
            jarId: allocationJarId,
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
      );
    }

    test(
      'persists expense and income transactions with jar allocations',
      () async {
        // Given
        final commands = [
          command(kind: TransactionKind.expense, allocationJarId: jarId),
          command(kind: TransactionKind.income, allocationJarId: jarId),
        ];

        // When
        final results = [
          for (final createCommand in commands) await service(createCommand),
        ];

        // Then
        expect(results, everyElement(isA<Success<Transaction>>()));
        expect(
          results.map((result) => result.valueOrNull!.splits.single.jarId),
          everyElement(jarId),
        );
        expect(
          (await transactionRepository.getAll()).valueOrNull,
          hasLength(2),
        );
      },
    );

    test(
      'persists expense and income transactions with valid categories',
      () async {
        // Given
        final commands = [
          command(
            kind: TransactionKind.expense,
            categoryId: expenseCategory.id,
          ),
          command(kind: TransactionKind.income, categoryId: incomeCategory.id),
        ];

        // When
        final results = [
          for (final createCommand in commands) await service(createCommand),
        ];

        // Then
        expect(results, everyElement(isA<Success<Transaction>>()));
        expect(
          (await transactionRepository.getAll()).valueOrNull,
          hasLength(2),
        );
      },
    );

    test('persists both allocation dimensions together', () async {
      // Given
      final createCommand = command(
        kind: TransactionKind.expense,
        categoryId: expenseCategory.id,
        allocationJarId: jarId,
      );

      // When
      final result = await service(createCommand);

      // Then
      final transaction = result.valueOrNull!;
      expect(transaction.splits.single.categoryId, expenseCategory.id);
      expect(transaction.splits.single.jarId, jarId);
      expect(
        (await transactionRepository.getById(transaction.id)).valueOrNull,
        same(transaction),
      );
    });

    test('rejects missing and incompatible category allocations', () async {
      // Given
      final missingCategoryCommand = command(
        kind: TransactionKind.expense,
        categoryId: CategoryId.fromString('missing'),
      );
      final incompatibleCategoryCommand = command(
        kind: TransactionKind.expense,
        categoryId: incomeCategory.id,
      );

      // When
      final missingResult = await service(missingCategoryCommand);
      final incompatibleResult = await service(incompatibleCategoryCommand);

      // Then
      expect(
        missingResult.failureOrNull,
        isA<AllocationCategoryNotFoundFailure>(),
      );
      expect(
        incompatibleResult.failureOrNull,
        isA<AllocationCategoryKindMismatchFailure>(),
      );
      expect((await transactionRepository.getAll()).valueOrNull, isEmpty);
    });
  });
}
