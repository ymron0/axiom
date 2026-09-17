@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_category_spending_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../mocks/get_categories_use_case_mock.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';
import '../../../mocks/query_transactions_use_case_mock.dart';

void main() {
  group('GetCategorySpendingService', () {
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetCategoriesUseCase getCategories;
    late MockGetSettingsUseCase getSettings;
    late MockQueryTransactionsUseCase queryTransactions;
    late GetCategorySpendingService service;

    late Category category;

    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    final effectiveFrom = DateTime.utc(2026, 1, 1);
    final effectiveUntil = DateTime.utc(2026, 2, 1);

    setUpAll(() {
      registerFallbackValue(TransactionQuery());
    });

    setUp(() {
      getCategoryById = MockGetCategoryByIdUseCase();
      getCategories = MockGetCategoriesUseCase();
      getSettings = MockGetSettingsUseCase();
      queryTransactions = MockQueryTransactionsUseCase();

      service = GetCategorySpendingService(
        getCategoryById: getCategoryById,
        getCategories: getCategories,
        getSettings: getSettings,
        queryTransactions: queryTransactions,
        calculator: const CategorySpendingCalculator(),
      );

      category = categoryFixture(id: 'groceries');

      when(
        () => getCategoryById(category.id),
      ).thenAnswer((_) async => Success<Category?>(category));

      when(() => getSettings()).thenAnswer(
        (_) async => Success<Settings?>(Settings(valuationCurrencyId: chf)),
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => const Success<List<Category>>([]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));
    });

    test(
      'returns zero totals when there are no matching allocations',
      () async {
        // When
        final result = await service(
          category.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.categoryId, category.id);
        expect(spending.kind, CategoryKind.expense);

        expect(spending.directTotal.assetId, chf);
        expect(spending.directTotal.amount, Decimal.zero);
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.zero);

        expect(spending.aggregateTotal.assetId, chf);
        expect(spending.aggregateTotal.amount, Decimal.zero);
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.zero);
      },
    );

    test(
      'uses persisted split valuation amounts instead of transaction amounts',
      () async {
        // Given
        final transaction = _transaction(
          id: 'eur-expense',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: category.id,
              transactionAmount: '100',
              valuationAmount: '94.25',
            ),
          ],
        );

        when(
          () => queryTransactions(any()),
        ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

        // When
        final result = await service(
          category.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.directTotal.assetId, chf);
        expect(spending.directTotal.amount, Decimal.parse('94.25'));
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.parse('94.25'));

        expect(spending.aggregateTotal.amount, Decimal.parse('94.25'));
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.parse('94.25'));
      },
    );

    test(
      'keeps direct parent spending separate from child aggregate spending',
      () async {
        // Given
        final parent = categoryFixture(id: 'household');

        final child = categoryFixture(
          id: 'groceries',
          parentCategoryId: parent.id.value,
        );

        final unrelated = categoryFixture(id: 'transport');

        when(
          () => getCategoryById(parent.id),
        ).thenAnswer((_) async => Success<Category?>(parent));

        when(() => getCategories()).thenAnswer(
          (_) async => Success<List<Category>>([parent, child, unrelated]),
        );

        final directTransaction = _transaction(
          id: 'direct-household',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: parent.id,
              transactionAmount: '20',
              valuationAmount: '18',
            ),
          ],
        );

        final childTransaction = _transaction(
          id: 'groceries-expense',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: child.id,
              transactionAmount: '10',
              valuationAmount: '9.50',
            ),
          ],
        );

        final unrelatedTransaction = _transaction(
          id: 'transport-expense',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: unrelated.id,
              transactionAmount: '500',
              valuationAmount: '475',
            ),
          ],
        );

        when(() => queryTransactions(any())).thenAnswer(
          (_) async => Success<List<Transaction>>([
            directTransaction,
            childTransaction,
            unrelatedTransaction,
          ]),
        );

        // When
        final result = await service(
          parent.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.directTotal.amount, Decimal.parse('18'));
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.parse('18'));

        expect(spending.aggregateTotal.amount, Decimal.parse('27.50'));
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.parse('27.50'));
      },
    );

    test(
      'includes an archived child in historical parent aggregation',
      () async {
        // Given
        final parent = categoryFixture(id: 'household');
        final archivedAt = DateTime.utc(2026, 2, 15);

        final archivedChild = categoryFixture(
          id: 'old-groceries',
          parentCategoryId: parent.id.value,
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        when(
          () => getCategoryById(parent.id),
        ).thenAnswer((_) async => Success<Category?>(parent));

        when(() => getCategories()).thenAnswer(
          (_) async => Success<List<Category>>([parent, archivedChild]),
        );

        final transaction = _transaction(
          id: 'historical-groceries',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          effectiveAt: DateTime.utc(2026, 1, 15),
          allocations: [
            _AllocationSpec(
              categoryId: archivedChild.id,
              transactionAmount: '50',
              valuationAmount: '47.50',
            ),
          ],
        );

        when(
          () => queryTransactions(any()),
        ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

        // When
        final result = await service(
          parent.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.directTotal.amount, Decimal.zero);
        expect(spending.directSignedValue, Decimal.zero);

        expect(spending.aggregateTotal.amount, Decimal.parse('47.50'));
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.parse('47.50'));
      },
    );

    test(
      'does not load the category collection for a child category',
      () async {
        // Given
        final child = categoryFixture(
          id: 'groceries',
          parentCategoryId: 'household',
        );

        when(
          () => getCategoryById(child.id),
        ).thenAnswer((_) async => Success<Category?>(child));

        final transaction = _transaction(
          id: 'child-expense',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: child.id,
              transactionAmount: '25',
              valuationAmount: '23',
            ),
          ],
        );

        when(
          () => queryTransactions(any()),
        ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

        // When
        final result = await service(
          child.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.directTotal.amount, Decimal.parse('23'));
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.parse('23'));

        expect(spending.aggregateTotal.amount, Decimal.parse('23'));
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.parse('23'));

        verifyNever(() => getCategories());
      },
    );

    test('queries all allocatable actual transactions for the requested UTC '
        'period', () async {
      // Given
      final from = DateTime.parse('2026-01-01T01:00:00+02:00');
      final until = DateTime.parse('2026-02-01T01:00:00+02:00');

      // When
      await service(category.id, effectiveFrom: from, effectiveUntil: until);

      // Then
      final captured =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(
        captured.kinds,
        equals({TransactionKind.expense, TransactionKind.income}),
      );

      expect(captured.states, equals({TransactionState.actual}));

      expect(captured.effectiveFrom, from.toUtc());
      expect(captured.effectiveUntil, until.toUtc());
    });

    test('returns incoming totals for an income category', () async {
      // Given
      final incomeCategory = categoryFixture(
        id: 'salary',
        kind: CategoryKind.income,
      );

      when(
        () => getCategoryById(incomeCategory.id),
      ).thenAnswer((_) async => Success<Category?>(incomeCategory));

      final transaction = _transaction(
        id: 'salary-income',
        kind: TransactionKind.income,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: incomeCategory.id,
            transactionAmount: '4000',
            valuationAmount: '3800',
          ),
        ],
      );

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

      // When
      final result = await service(
        incomeCategory.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      final spending = result.valueOrNull!;

      expect(spending.kind, CategoryKind.income);

      expect(spending.directTotal.amount, Decimal.parse('3800'));
      expect(spending.directTotal.isIncoming, isTrue);
      expect(spending.directSignedValue, Decimal.parse('3800'));

      expect(spending.aggregateTotal.amount, Decimal.parse('3800'));
      expect(spending.aggregateTotal.isIncoming, isTrue);
      expect(spending.aggregateSignedValue, Decimal.parse('3800'));

      final captured =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(
        captured.kinds,
        equals({TransactionKind.expense, TransactionKind.income}),
      );

      expect(captured.states, equals({TransactionState.actual}));
    });

    test(
      'nets income against expenses posted to an expense category',
      () async {
        // Given
        final insuranceCategory = categoryFixture(
          id: 'insurances',
          kind: CategoryKind.expense,
        );

        when(
          () => getCategoryById(insuranceCategory.id),
        ).thenAnswer((_) async => Success<Category?>(insuranceCategory));

        final premium = _transaction(
          id: 'insurance-premium',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: insuranceCategory.id,
              transactionAmount: '200',
              valuationAmount: '200',
            ),
          ],
        );

        final reimbursement = _transaction(
          id: 'insurance-reimbursement',
          kind: TransactionKind.income,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: insuranceCategory.id,
              transactionAmount: '75',
              valuationAmount: '75',
            ),
          ],
        );

        when(() => queryTransactions(any())).thenAnswer(
          (_) async => Success<List<Transaction>>([premium, reimbursement]),
        );

        // When
        final result = await service(
          insuranceCategory.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.kind, CategoryKind.expense);

        expect(spending.directTotal.amount, Decimal.parse('125'));
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.parse('125'));

        expect(spending.aggregateTotal.amount, Decimal.parse('125'));
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.parse('125'));
      },
    );

    test('allows an expense category to become negative when income exceeds '
        'expenses', () async {
      // Given
      final insuranceCategory = categoryFixture(
        id: 'insurances',
        kind: CategoryKind.expense,
      );

      when(
        () => getCategoryById(insuranceCategory.id),
      ).thenAnswer((_) async => Success<Category?>(insuranceCategory));

      final premium = _transaction(
        id: 'insurance-premium',
        kind: TransactionKind.expense,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: insuranceCategory.id,
            transactionAmount: '200',
            valuationAmount: '200',
          ),
        ],
      );

      final reimbursement = _transaction(
        id: 'insurance-reimbursement',
        kind: TransactionKind.income,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: insuranceCategory.id,
            transactionAmount: '350',
            valuationAmount: '350',
          ),
        ],
      );

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([premium, reimbursement]),
      );

      // When
      final result = await service(
        insuranceCategory.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      final spending = result.valueOrNull!;

      expect(spending.kind, CategoryKind.expense);

      // The real financial net flow is CHF 150 incoming.
      expect(spending.directTotal.assetId, chf);
      expect(spending.directTotal.amount, Decimal.parse('150'));
      expect(spending.directTotal.isIncoming, isTrue);

      // Relative to an expense category, this means -CHF 150 spending.
      expect(spending.directSignedValue, Decimal.parse('-150'));

      expect(spending.aggregateTotal.assetId, chf);
      expect(spending.aggregateTotal.amount, Decimal.parse('150'));
      expect(spending.aggregateTotal.isIncoming, isTrue);
      expect(spending.aggregateSignedValue, Decimal.parse('-150'));
    });

    test('nets expenses against income posted to an income category', () async {
      // Given
      final incomeCategory = categoryFixture(
        id: 'salary',
        kind: CategoryKind.income,
      );

      when(
        () => getCategoryById(incomeCategory.id),
      ).thenAnswer((_) async => Success<Category?>(incomeCategory));

      final salary = _transaction(
        id: 'salary-income',
        kind: TransactionKind.income,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: incomeCategory.id,
            transactionAmount: '1000',
            valuationAmount: '1000',
          ),
        ],
      );

      final repayment = _transaction(
        id: 'salary-repayment',
        kind: TransactionKind.expense,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: incomeCategory.id,
            transactionAmount: '250',
            valuationAmount: '250',
          ),
        ],
      );

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([salary, repayment]),
      );

      // When
      final result = await service(
        incomeCategory.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      final spending = result.valueOrNull!;

      expect(spending.kind, CategoryKind.income);

      expect(spending.directTotal.amount, Decimal.parse('750'));
      expect(spending.directTotal.isIncoming, isTrue);
      expect(spending.directSignedValue, Decimal.parse('750'));

      expect(spending.aggregateTotal.amount, Decimal.parse('750'));
      expect(spending.aggregateTotal.isIncoming, isTrue);
      expect(spending.aggregateSignedValue, Decimal.parse('750'));
    });

    test('allows an income category to become negative when expenses exceed '
        'income', () async {
      // Given
      final incomeCategory = categoryFixture(
        id: 'salary',
        kind: CategoryKind.income,
      );

      when(
        () => getCategoryById(incomeCategory.id),
      ).thenAnswer((_) async => Success<Category?>(incomeCategory));

      final salary = _transaction(
        id: 'salary-income',
        kind: TransactionKind.income,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: incomeCategory.id,
            transactionAmount: '100',
            valuationAmount: '100',
          ),
        ],
      );

      final repayment = _transaction(
        id: 'salary-repayment',
        kind: TransactionKind.expense,
        transactionAssetId: eur,
        valuationAssetId: chf,
        allocations: [
          _AllocationSpec(
            categoryId: incomeCategory.id,
            transactionAmount: '150',
            valuationAmount: '150',
          ),
        ],
      );

      when(() => queryTransactions(any())).thenAnswer(
        (_) async => Success<List<Transaction>>([salary, repayment]),
      );

      // When
      final result = await service(
        incomeCategory.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      final spending = result.valueOrNull!;

      expect(spending.kind, CategoryKind.income);

      expect(spending.directTotal.amount, Decimal.parse('50'));
      expect(spending.directTotal.isOutgoing, isTrue);
      expect(spending.directSignedValue, Decimal.parse('-50'));

      expect(spending.aggregateTotal.amount, Decimal.parse('50'));
      expect(spending.aggregateTotal.isOutgoing, isTrue);
      expect(spending.aggregateSignedValue, Decimal.parse('-50'));
    });

    test(
      'nets opposite-direction child activity into the parent aggregate',
      () async {
        // Given
        final parent = categoryFixture(
          id: 'insurances',
          kind: CategoryKind.expense,
        );

        final child = categoryFixture(
          id: 'health-insurance',
          parentCategoryId: parent.id.value,
          kind: CategoryKind.expense,
        );

        when(
          () => getCategoryById(parent.id),
        ).thenAnswer((_) async => Success<Category?>(parent));

        when(
          () => getCategories(),
        ).thenAnswer((_) async => Success<List<Category>>([parent, child]));

        final directPremium = _transaction(
          id: 'direct-premium',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: parent.id,
              transactionAmount: '100',
              valuationAmount: '100',
            ),
          ],
        );

        final childReimbursement = _transaction(
          id: 'child-reimbursement',
          kind: TransactionKind.income,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: child.id,
              transactionAmount: '150',
              valuationAmount: '150',
            ),
          ],
        );

        when(() => queryTransactions(any())).thenAnswer(
          (_) async =>
              Success<List<Transaction>>([directPremium, childReimbursement]),
        );

        // When
        final result = await service(
          parent.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.directTotal.amount, Decimal.parse('100'));
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.parse('100'));

        expect(spending.aggregateTotal.amount, Decimal.parse('50'));
        expect(spending.aggregateTotal.isIncoming, isTrue);
        expect(spending.aggregateSignedValue, Decimal.parse('-50'));
      },
    );

    test(
      'returns deterministic category zero when opposite flows cancel exactly',
      () async {
        // Given
        final insuranceCategory = categoryFixture(
          id: 'insurances',
          kind: CategoryKind.expense,
        );

        when(
          () => getCategoryById(insuranceCategory.id),
        ).thenAnswer((_) async => Success<Category?>(insuranceCategory));

        final premium = _transaction(
          id: 'insurance-premium',
          kind: TransactionKind.expense,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: insuranceCategory.id,
              transactionAmount: '200',
              valuationAmount: '200',
            ),
          ],
        );

        final reimbursement = _transaction(
          id: 'insurance-reimbursement',
          kind: TransactionKind.income,
          transactionAssetId: eur,
          valuationAssetId: chf,
          allocations: [
            _AllocationSpec(
              categoryId: insuranceCategory.id,
              transactionAmount: '200',
              valuationAmount: '200',
            ),
          ],
        );

        when(() => queryTransactions(any())).thenAnswer(
          (_) async => Success<List<Transaction>>([reimbursement, premium]),
        );

        // When
        final result = await service(
          insuranceCategory.id,
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveUntil,
        );

        // Then
        final spending = result.valueOrNull!;

        expect(spending.directTotal.amount, Decimal.zero);

        // Expense-category zero has a deterministic outgoing representation.
        expect(spending.directTotal.isOutgoing, isTrue);
        expect(spending.directSignedValue, Decimal.zero);

        expect(spending.aggregateTotal.amount, Decimal.zero);
        expect(spending.aggregateTotal.isOutgoing, isTrue);
        expect(spending.aggregateSignedValue, Decimal.zero);
      },
    );

    test('rejects an invalid period before loading dependencies', () async {
      // Given
      final from = DateTime.utc(2026, 2, 1);
      final until = DateTime.utc(2026, 1, 1);

      // When / Then
      expect(
        () => service(category.id, effectiveFrom: from, effectiveUntil: until),
        throwsArgumentError,
      );

      verifyNever(() => getCategoryById(category.id));
      verifyNever(() => getSettings());
      verifyNever(() => getCategories());
      verifyNever(() => queryTransactions(any()));
    });

    test('returns category-not-found when the category is absent', () async {
      // Given
      when(
        () => getCategoryById(category.id),
      ).thenAnswer((_) async => const Success<Category?>(null));

      // When
      final result = await service(
        category.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, isA<CategoryNotFoundFailure>());

      verifyNever(() => getSettings());
      verifyNever(() => getCategories());
      verifyNever(() => queryTransactions(any()));
    });

    test('propagates category lookup failures', () async {
      // Given
      const failure = CategoryNotFoundFailure(message: 'category read failed');

      when(() => getCategoryById(category.id)).thenAnswer((_) async => failure);

      // When
      final result = await service(
        category.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => getSettings());
      verifyNever(() => getCategories());
      verifyNever(() => queryTransactions(any()));
    });

    test('returns settings-not-initialized when settings are absent', () async {
      // Given
      when(
        () => getSettings(),
      ).thenAnswer((_) async => const Success<Settings?>(null));

      // When
      final result = await service(
        category.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());

      verifyNever(() => getCategories());
      verifyNever(() => queryTransactions(any()));
    });

    test('propagates settings lookup failures', () async {
      // Given
      const failure = SettingsNotInitializedFailure(
        message: 'settings read failed',
      );

      when(() => getSettings()).thenAnswer((_) async => failure);

      // When
      final result = await service(
        category.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => getCategories());
      verifyNever(() => queryTransactions(any()));
    });

    test('propagates category collection lookup failures', () async {
      // Given
      const failure = CategoryNotFoundFailure(
        message: 'category collection read failed',
      );

      when(() => getCategories()).thenAnswer((_) async => failure);

      // When
      final result = await service(
        category.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => queryTransactions(any()));
    });

    test('propagates transaction query failures', () async {
      // Given
      const failure = TransactionNotFoundFailure(
        message: 'transaction query failed',
      );

      when(() => queryTransactions(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(
        category.id,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
      );

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}

final class _AllocationSpec {
  final CategoryId categoryId;
  final String transactionAmount;
  final String valuationAmount;

  const _AllocationSpec({
    required this.categoryId,
    required this.transactionAmount,
    required this.valuationAmount,
  });
}

Transaction _transaction({
  required String id,
  required TransactionKind kind,
  required AssetId transactionAssetId,
  required AssetId valuationAssetId,
  required List<_AllocationSpec> allocations,
  DateTime? effectiveAt,
}) {
  if (kind != TransactionKind.expense && kind != TransactionKind.income) {
    throw ArgumentError.value(
      kind,
      'kind',
      'Test helper supports only expense and income transactions.',
    );
  }

  final incoming = kind == TransactionKind.income;

  AssetAmount amount({required AssetId assetId, required Decimal value}) {
    return incoming
        ? AssetAmount.incoming(assetId: assetId, amount: value)
        : AssetAmount.outgoing(assetId: assetId, amount: value);
  }

  var transactionTotal = Decimal.zero;
  var valuationTotal = Decimal.zero;

  final splits = <TransactionSplit>[];

  for (final allocation in allocations) {
    final transactionValue = Decimal.parse(allocation.transactionAmount);

    final valuationValue = Decimal.parse(allocation.valuationAmount);

    transactionTotal += transactionValue;
    valuationTotal += valuationValue;

    splits.add(
      TransactionSplit(
        transactionAmount: amount(
          assetId: transactionAssetId,
          value: transactionValue,
        ),
        valuationAmount: amount(
          assetId: valuationAssetId,
          value: valuationValue,
        ),
        categoryId: allocation.categoryId,
      ),
    );
  }

  final transactionAmount = amount(
    assetId: transactionAssetId,
    value: transactionTotal,
  );

  final valuationAmount = amount(
    assetId: valuationAssetId,
    value: valuationTotal,
  );

  final timestamp = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString(id),
    kind: kind,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 15),
    description: 'Category spending test transaction',
    note: null,
    state: TransactionState.actual,
    splits: splits,
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-$id'),
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: valuationAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
