import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(CategoryId.fromString('mock-category-id'));
  });

  group('ValidateTransactionAllocationsService', () {
    late MockGetCategoryByIdUseCase getCategoryById;
    late ValidateTransactionAllocationsService service;

    setUp(() {
      getCategoryById = MockGetCategoryByIdUseCase();

      service = ValidateTransactionAllocationsService(
        getCategoryById: getCategoryById,
      );
    });

    test(
      'succeeds when transaction contains no category allocations',
      () async {
        // Given
        final transaction = _transaction(
          kind: TransactionKind.expense,
          splits: const [],
        );

        // When
        final result = await service(transaction);

        // Then
        expect(result.isSuccess, isTrue);
        verifyNever(() => getCategoryById(any()));
      },
    );

    test(
      'succeeds when expense category exists and has expense kind',
      () async {
        // Given
        final category = categoryFixture(
          id: 'groceries',
          kind: CategoryKind.expense,
        );

        final transaction = _transaction(
          kind: TransactionKind.expense,
          splits: [
            _categorySplit(
              categoryId: category.id,
              amount: 10,
              direction: AssetAmountDirection.outgoing,
            ),
          ],
        );

        when(
          () => getCategoryById(any<CategoryId>()),
        ).thenAnswer((_) async => Success<Category?>(category));

        // When
        final result = await service(transaction);

        // Then
        expect(result.isSuccess, isTrue);
        verify(() => getCategoryById(category.id)).called(1);
      },
    );

    test('succeeds when income category exists and has income kind', () async {
      // Given
      final category = categoryFixture(id: 'salary', kind: CategoryKind.income);

      final transaction = _transaction(
        kind: TransactionKind.income,
        splits: [
          _categorySplit(
            categoryId: category.id,
            amount: 10,
            direction: AssetAmountDirection.incoming,
          ),
        ],
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => Success<Category?>(category));

      // When
      final result = await service(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => getCategoryById(category.id)).called(1);
    });

    test('fails when referenced category does not exist', () async {
      // Given
      final categoryId = CategoryId.fromString('missing-category');

      final transaction = _transaction(
        kind: TransactionKind.expense,
        splits: [
          _categorySplit(
            categoryId: categoryId,
            amount: 10,
            direction: AssetAmountDirection.outgoing,
          ),
        ],
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());
      expect(result.failureOrNull?.message, contains(categoryId.value));

      verify(() => getCategoryById(categoryId)).called(1);
    });

    test('fails when expense transaction references income category', () async {
      // Given
      final category = categoryFixture(id: 'salary', kind: CategoryKind.income);

      final transaction = _transaction(
        kind: TransactionKind.expense,
        splits: [
          _categorySplit(
            categoryId: category.id,
            amount: 10,
            direction: AssetAmountDirection.outgoing,
          ),
        ],
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => Success<Category?>(category));

      // When
      final result = await service(transaction);

      // Then
      expect(
        result.failureOrNull,
        isA<AllocationCategoryKindMismatchFailure>(),
      );
      expect(
        result.failureOrNull?.message,
        allOf(
          contains(category.id.value),
          contains(CategoryKind.income.name),
          contains(CategoryKind.expense.name),
        ),
      );
    });

    test('fails when income transaction references expense category', () async {
      // Given
      final category = categoryFixture(
        id: 'groceries',
        kind: CategoryKind.expense,
      );

      final transaction = _transaction(
        kind: TransactionKind.income,
        splits: [
          _categorySplit(
            categoryId: category.id,
            amount: 10,
            direction: AssetAmountDirection.incoming,
          ),
        ],
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => Success<Category?>(category));

      // When
      final result = await service(transaction);

      // Then
      expect(
        result.failureOrNull,
        isA<AllocationCategoryKindMismatchFailure>(),
      );
    });

    test('propagates category lookup failures unchanged', () async {
      // Given
      final categoryId = CategoryId.fromString('lookup-failure');

      final transaction = _transaction(
        kind: TransactionKind.expense,
        splits: [
          _categorySplit(
            categoryId: categoryId,
            amount: 10,
            direction: AssetAmountDirection.outgoing,
          ),
        ],
      );

      const failure = CategoryNotFoundFailure(
        message: 'Category lookup failed.',
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('resolves each distinct category only once', () async {
      // Given
      final category = categoryFixture(
        id: 'groceries',
        kind: CategoryKind.expense,
      );

      final transaction = _transaction(
        kind: TransactionKind.expense,
        splits: [
          _categorySplit(
            categoryId: category.id,
            amount: 4,
            direction: AssetAmountDirection.outgoing,
          ),
          _categorySplit(
            categoryId: category.id,
            amount: 6,
            direction: AssetAmountDirection.outgoing,
          ),
        ],
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => Success<Category?>(category));

      // When
      final result = await service(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => getCategoryById(category.id)).called(1);
    });

    test('stops validation after the first invalid category', () async {
      // Given
      final missingId = CategoryId.fromString('missing');
      final secondId = CategoryId.fromString('second');

      final transaction = _transaction(
        kind: TransactionKind.expense,
        splits: [
          _categorySplit(
            categoryId: missingId,
            amount: 4,
            direction: AssetAmountDirection.outgoing,
          ),
          _categorySplit(
            categoryId: secondId,
            amount: 6,
            direction: AssetAmountDirection.outgoing,
          ),
        ],
      );

      when(
        () => getCategoryById(any<CategoryId>()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());

      verify(() => getCategoryById(missingId)).called(1);
      verifyNever(() => getCategoryById(secondId));
    });
  });
}

TransactionSplit _categorySplit({
  required CategoryId categoryId,
  required int amount,
  required AssetAmountDirection direction,
}) {
  final assetAmount = AssetAmount(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.fromInt(amount),
    direction: direction,
  );

  return TransactionSplit(
    transactionAmount: assetAmount,
    valuationAmount: assetAmount,
    categoryId: categoryId,
  );
}

Transaction _transaction({
  required TransactionKind kind,
  required List<TransactionSplit> splits,
}) {
  final direction = switch (kind) {
    TransactionKind.expense => AssetAmountDirection.outgoing,
    TransactionKind.income => AssetAmountDirection.incoming,
    TransactionKind.transfer => throw ArgumentError.value(
      kind,
      'kind',
      'This test helper supports allocation-capable transaction kinds only.',
    ),
    TransactionKind.balanceCorrection => throw ArgumentError.value(
      kind,
      'kind',
      'This test helper supports allocation-capable transaction kinds only.',
    ),
  };

  final total = splits.isEmpty
      ? Decimal.fromInt(10)
      : splits.fold(
          Decimal.zero,
          (sum, split) => sum + split.transactionAmount.amount,
        );

  final amount = AssetAmount(
    assetId: AssetId.fromString('asset-chf'),
    amount: total,
    direction: direction,
  );

  final timestamp = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString('allocation-validation-transaction'),
    kind: kind,
    merchantId: MerchantId.self,
    effectiveAt: timestamp,
    description: 'Allocation validation',
    state: TransactionState.actual,
    splits: splits,
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-chf'),
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
