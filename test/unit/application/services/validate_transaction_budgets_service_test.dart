@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../mocks/get_categories_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';
import '../../../mocks/query_transactions_use_case_mock.dart';

void main() {
  group('ValidateTransactionBudgetsService', () {
    final chf = AssetId.fromString('asset-chf');

    late MockGetSettingsUseCase getSettings;
    late MockGetCategoriesUseCase getCategories;
    late MockQueryTransactionsUseCase queryTransactions;
    late ValidateTransactionBudgetsService service;

    setUpAll(() {
      registerFallbackValue(TransactionQuery());
    });

    setUp(() {
      getSettings = MockGetSettingsUseCase();
      getCategories = MockGetCategoriesUseCase();
      queryTransactions = MockQueryTransactionsUseCase();

      service = ValidateTransactionBudgetsService(
        getSettings: getSettings,
        getCategories: getCategories,
        queryTransactions: queryTransactions,
        calculator: const CategorySpendingCalculator(),
      );

      when(() => getSettings()).thenAnswer(
        (_) async => Success<Settings?>(
          Settings(
            valuationCurrencyId: chf,
            allowOverbudgetTransactions: false,
          ),
        ),
      );

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));
    });

    test(
      'allows an overbudget transaction when the setting is enabled',
      () async {
        final category = _category(
          id: 'groceries',
          budget: _budget(chf, limit: '100'),
        );

        final candidate = _transaction(
          id: 'candidate',
          categoryId: category.id,
          amount: '1000',
        );

        when(() => getSettings()).thenAnswer(
          (_) async => Success<Settings?>(
            Settings(
              valuationCurrencyId: chf,
              allowOverbudgetTransactions: true,
            ),
          ),
        );

        final result = await service(candidate);

        expect(result.isSuccess, isTrue);

        verifyNever(() => getCategories());
        verifyNever(() => queryTransactions(any()));
      },
    );

    test(
      'rejects an overbudget transaction when the setting is disabled',
      () async {
        final category = _category(
          id: 'groceries',
          budget: _budget(chf, limit: '100'),
        );

        final existing = _transaction(
          id: 'existing',
          categoryId: category.id,
          amount: '90',
        );

        final candidate = _transaction(
          id: 'candidate',
          categoryId: category.id,
          amount: '20',
        );

        when(
          () => getCategories(),
        ).thenAnswer((_) async => Success<List<Category>>([category]));

        when(
          () => queryTransactions(any()),
        ).thenAnswer((_) async => Success<List<Transaction>>([existing]));

        final result = await service(candidate);

        expect(
          result.failureOrNull,
          isA<TransactionWouldExceedBudgetFailure>(),
        );

        expect(result.failureOrNull?.message, contains('Projected usage: 110'));

        expect(result.failureOrNull?.message, contains('Budget limit: 100'));
      },
    );

    test('allows a transaction that reaches the limit exactly', () async {
      final category = _category(
        id: 'groceries',
        budget: _budget(chf, limit: '100'),
      );

      final existing = _transaction(
        id: 'existing',
        categoryId: category.id,
        amount: '90',
      );

      final candidate = _transaction(
        id: 'candidate',
        categoryId: category.id,
        amount: '10',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([existing]));

      final result = await service(candidate);

      expect(result.isSuccess, isTrue);
    });

    test('enforces a parent budget for child allocations', () async {
      final parent = _category(
        id: 'household',
        budget: _budget(chf, limit: '100'),
      );

      final child = _category(id: 'groceries', parentCategoryId: parent.id);

      final existing = _transaction(
        id: 'existing',
        categoryId: child.id,
        amount: '90',
      );

      final candidate = _transaction(
        id: 'candidate',
        categoryId: child.id,
        amount: '20',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([parent, child]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([existing]));

      final result = await service(candidate);

      expect(result.failureOrNull, isA<TransactionWouldExceedBudgetFailure>());

      expect(result.failureOrNull?.message, contains('household'));
    });

    test('allows a refund that reduces expense usage', () async {
      final category = _category(
        id: 'insurance',
        budget: _budget(chf, limit: '100'),
      );

      final existing = _transaction(
        id: 'premium',
        categoryId: category.id,
        amount: '120',
      );

      final refund = _transaction(
        id: 'refund',
        categoryId: category.id,
        amount: '30',
        kind: TransactionKind.income,
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([existing]));

      final result = await service(refund);

      expect(result.isSuccess, isTrue);
    });

    test('rejects additional spending when already over budget', () async {
      final category = _category(
        id: 'groceries',
        budget: _budget(chf, limit: '100'),
      );

      final existing = _transaction(
        id: 'existing',
        categoryId: category.id,
        amount: '120',
      );

      final candidate = _transaction(
        id: 'candidate',
        categoryId: category.id,
        amount: '5',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([existing]));

      final result = await service(candidate);

      expect(result.failureOrNull, isA<TransactionWouldExceedBudgetFailure>());
    });

    test('allows an unchanged update when already over budget', () async {
      final category = _category(
        id: 'groceries',
        budget: _budget(chf, limit: '100'),
      );

      final previous = _transaction(
        id: 'same',
        categoryId: category.id,
        amount: '120',
      );

      final replacement = _transaction(
        id: 'same',
        categoryId: category.id,
        amount: '120',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([previous]));

      final result = await service(replacement, previous: previous);

      expect(result.isSuccess, isTrue);
    });

    test(
      'allows an update that reduces an existing overbudget amount',
      () async {
        final category = _category(
          id: 'groceries',
          budget: _budget(chf, limit: '100'),
        );

        final previous = _transaction(
          id: 'same',
          categoryId: category.id,
          amount: '120',
        );

        final replacement = _transaction(
          id: 'same',
          categoryId: category.id,
          amount: '110',
        );

        when(
          () => getCategories(),
        ).thenAnswer((_) async => Success<List<Category>>([category]));

        when(
          () => queryTransactions(any()),
        ).thenAnswer((_) async => Success<List<Transaction>>([previous]));

        final result = await service(replacement, previous: previous);

        expect(result.isSuccess, isTrue);
      },
    );

    test('rejects an update that increases usage beyond the limit', () async {
      final category = _category(
        id: 'groceries',
        budget: _budget(chf, limit: '100'),
      );

      final previous = _transaction(
        id: 'same',
        categoryId: category.id,
        amount: '90',
      );

      final replacement = _transaction(
        id: 'same',
        categoryId: category.id,
        amount: '110',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      when(
        () => queryTransactions(any()),
      ).thenAnswer((_) async => Success<List<Transaction>>([previous]));

      final result = await service(replacement, previous: previous);

      expect(result.failureOrNull, isA<TransactionWouldExceedBudgetFailure>());
    });

    test(
      'does not subtract the old transaction from a different period',
      () async {
        final category = _category(
          id: 'groceries',
          budget: _budget(chf, limit: '100'),
        );

        final previous = _transaction(
          id: 'same',
          categoryId: category.id,
          amount: '90',
          effectiveAt: DateTime.utc(2026, 1, 15),
        );

        final replacement = _transaction(
          id: 'same',
          categoryId: category.id,
          amount: '110',
          effectiveAt: DateTime.utc(2026, 2, 15),
        );

        when(
          () => getCategories(),
        ).thenAnswer((_) async => Success<List<Category>>([category]));

        when(
          () => queryTransactions(any()),
        ).thenAnswer((_) async => const Success<List<Transaction>>([]));

        final result = await service(replacement, previous: previous);

        expect(
          result.failureOrNull,
          isA<TransactionWouldExceedBudgetFailure>(),
        );
      },
    );

    test('does not enforce budgets for planned transactions', () async {
      final planned = _transaction(
        id: 'planned',
        categoryId: CategoryId.fromString('groceries'),
        amount: '1000',
        state: TransactionState.planned,
      );

      final result = await service(planned);

      expect(result.isSuccess, isTrue);

      verifyNever(() => getSettings());
      verifyNever(() => getCategories());
      verifyNever(() => queryTransactions(any()));
    });

    test(
      'does not load budget configuration without category allocations',
      () async {
        final transaction = _transaction(id: 'unallocated', amount: '1000');

        final result = await service(transaction);

        expect(result.isSuccess, isTrue);

        verifyNever(() => getSettings());
        verifyNever(() => getCategories());
        verifyNever(() => queryTransactions(any()));
      },
    );

    test('skips categories without an effective budget', () async {
      final category = _category(id: 'groceries');

      final transaction = _transaction(
        id: 'candidate',
        categoryId: category.id,
        amount: '1000',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      final result = await service(transaction);

      expect(result.isSuccess, isTrue);

      verifyNever(() => queryTransactions(any()));
    });

    test('clips monthly queries to budget effective dates', () async {
      final category = _category(
        id: 'groceries',
        budget: _budget(
          chf,
          limit: '100',
          effectiveFrom: CalendarDate(2026, 1, 10),
          effectiveUntil: CalendarDate(2026, 1, 20),
        ),
      );

      final transaction = _transaction(
        id: 'candidate',
        categoryId: category.id,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 1, 15),
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      await service(transaction);

      final query =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(query.effectiveFrom, DateTime.utc(2026, 1, 10));

      expect(query.effectiveUntil, DateTime.utc(2026, 1, 20));
    });

    test('uses calendar-year boundaries for yearly budgets', () async {
      final category = _category(
        id: 'travel',
        budget: _budget(chf, limit: '5000', period: BudgetPeriod.yearly),
      );

      final transaction = _transaction(
        id: 'candidate',
        categoryId: category.id,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 6, 15),
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      await service(transaction);

      final query =
          verify(() => queryTransactions(captureAny())).captured.single
              as TransactionQuery;

      expect(query.effectiveFrom, DateTime.utc(2026, 1, 1));

      expect(query.effectiveUntil, DateTime.utc(2027, 1, 1));
    });

    test('returns settings-not-initialized failure', () async {
      final transaction = _transaction(
        id: 'candidate',
        categoryId: CategoryId.fromString('groceries'),
        amount: '10',
      );

      when(
        () => getSettings(),
      ).thenAnswer((_) async => const Success<Settings?>(null));

      final result = await service(transaction);

      expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());

      verifyNever(() => getCategories());
    });

    test('propagates settings failures', () async {
      final transaction = _transaction(
        id: 'candidate',
        categoryId: CategoryId.fromString('groceries'),
        amount: '10',
      );

      const failure = SettingsRepositoryFailure(message: 'settings failed');

      when(() => getSettings()).thenAnswer((_) async => failure);

      final result = await service(transaction);

      expect(result.failureOrNull, same(failure));

      verifyNever(() => getCategories());
    });

    test('returns failure for a missing allocated category', () async {
      final transaction = _transaction(
        id: 'candidate',
        categoryId: CategoryId.fromString('missing'),
        amount: '10',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => const Success<List<Category>>([]));

      final result = await service(transaction);

      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());

      verifyNever(() => queryTransactions(any()));
    });

    test(
      'returns failure when an allocated category references a missing parent',
      () async {
        final parentId = CategoryId.fromString('missing-parent');
        final child = _category(id: 'groceries', parentCategoryId: parentId);

        final transaction = _transaction(
          id: 'candidate',
          categoryId: child.id,
          amount: '10',
        );

        when(
          () => getCategories(),
        ).thenAnswer((_) async => Success<List<Category>>([child]));

        final result = await service(transaction);

        expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());
        expect(
          result.failureOrNull?.message,
          'Transaction allocation references a category whose parent does not '
          'exist: missing-parent',
        );

        verifyNever(() => queryTransactions(any()));
      },
    );

    test('propagates category failures', () async {
      final transaction = _transaction(
        id: 'candidate',
        categoryId: CategoryId.fromString('groceries'),
        amount: '10',
      );

      const failure = CategoryNotFoundFailure(message: 'categories failed');

      when(() => getCategories()).thenAnswer((_) async => failure);

      final result = await service(transaction);

      expect(result.failureOrNull, same(failure));

      verifyNever(() => queryTransactions(any()));
    });

    test('propagates transaction query failures', () async {
      final category = _category(
        id: 'groceries',
        budget: _budget(chf, limit: '100'),
      );

      final transaction = _transaction(
        id: 'candidate',
        categoryId: category.id,
        amount: '10',
      );

      const failure = TransactionRepositoryFailure(
        message: 'transactions failed',
      );

      when(
        () => getCategories(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));

      when(() => queryTransactions(any())).thenAnswer((_) async => failure);

      final result = await service(transaction);

      expect(result.failureOrNull, same(failure));
    });

    test('rejects mismatched previous transaction identity', () {
      final previous = _transaction(id: 'previous', amount: '10');

      final replacement = _transaction(id: 'replacement', amount: '10');

      expect(
        () => service(replacement, previous: previous),
        throwsArgumentError,
      );
    });
  });
}

Category _category({
  required String id,
  CategoryId? parentCategoryId,
  CategoryKind kind = CategoryKind.expense,
  CategoryBudget? budget,
}) {
  final timestamp = DateTime.utc(2026, 1, 1);

  return Category(
    id: CategoryId.fromString(id),
    name: id,
    parentCategoryId: parentCategoryId,
    kind: kind,
    budgets: [?budget],
    icon: EntityIcon.other,
    color: EntityColor.blue,
    sortOrder: 0,
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}

CategoryBudget _budget(
  AssetId assetId, {
  required String limit,
  BudgetPeriod period = BudgetPeriod.monthly,
  CalendarDate? effectiveFrom,
  CalendarDate? effectiveUntil,
}) {
  return CategoryBudget(
    limit: AssetAmount.incoming(assetId: assetId, amount: Decimal.parse(limit)),
    period: period,
    effectiveFrom: effectiveFrom ?? CalendarDate(2026, 1, 1),
    effectiveUntil: effectiveUntil,
  );
}

Transaction _transaction({
  required String id,
  required String amount,
  CategoryId? categoryId,
  TransactionKind kind = TransactionKind.expense,
  TransactionState state = TransactionState.actual,
  DateTime? effectiveAt,
}) {
  if (kind != TransactionKind.expense && kind != TransactionKind.income) {
    throw ArgumentError.value(
      kind,
      'kind',
      'Budget tests support expense and income transactions only.',
    );
  }

  final assetId = AssetId.fromString('asset-chf');
  final value = Decimal.parse(amount);

  final AssetAmount assetAmount = kind == TransactionKind.income
      ? AssetAmount.incoming(assetId: assetId, amount: value)
      : AssetAmount.outgoing(assetId: assetId, amount: value);

  final timestamp = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString(id),
    kind: kind,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 15),
    description: 'Budget test transaction',
    state: state,
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
        accountId: AccountId.fromString('account-$id'),
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
