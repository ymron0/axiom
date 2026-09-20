import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_spending.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:decimal/decimal.dart';

/// Validates whether a transaction is permitted by the configured budget
/// enforcement policy.
///
/// ## Configuration
///
/// Budget enforcement is controlled by
/// `Settings.allowOverbudgetTransactions`.
///
/// When it is `true`, this service succeeds without loading categories or
/// existing transactions.
///
/// When it is `false`, actual transactions are checked against every applicable
/// category budget.
///
/// ## Planned transactions
///
/// Planned transactions do not consume actual budgets and are never rejected
/// by this service.
///
/// Converting a planned transaction to actual is checked because that workflow
/// ultimately passes the replacement through `UpdateTransactionService`.
///
/// ## Hierarchy
///
/// A child-category allocation contributes to:
///
/// - the child's budget, when defined; and
/// - its parent category's budget, when defined.
///
/// ## Direction
///
/// Category spending uses the existing category netting semantics.
///
/// Consequently refunds and reimbursements reduce expense-category usage rather
/// than increasing it.
///
/// ## Updates
///
/// When [previous] is supplied, its existing contribution is removed before
/// the replacement contribution is applied.
///
/// An already-overbudget transaction may therefore be edited when the edit does
/// not worsen the budget.
///
/// A change is rejected only when:
///
/// 1. projected usage exceeds the applicable limit; and
/// 2. projected usage is greater than current persisted usage.
class ValidateTransactionBudgetsService {
  final GetSettingsUseCase _getSettings;
  final GetCategoriesUseCase _getCategories;
  final QueryTransactionsUseCase _queryTransactions;
  final CategorySpendingCalculator _calculator;

  /// Creates the budget validator.
  const ValidateTransactionBudgetsService({
    required GetSettingsUseCase getSettings,
    required GetCategoriesUseCase getCategories,
    required QueryTransactionsUseCase queryTransactions,
    required CategorySpendingCalculator calculator,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getCategories = getCategories, // ignore: prefer_initializing_formals
       _queryTransactions = // ignore: prefer_initializing_formals
           queryTransactions,
       _calculator = calculator; // ignore: prefer_initializing_formals

  /// Validates [transaction].
  ///
  /// Supply [previous] when [transaction] replaces an already persisted
  /// transaction.
  Future<Result<void, BaseFailure>> call(
    Transaction transaction, {
    Transaction? previous,
  }) async {
    if (previous != null && previous.id != transaction.id) {
      throw ArgumentError.value(
        previous.id,
        'previous',
        'Previous and replacement transactions must have the same identity.',
      );
    }

    if (transaction.state != TransactionState.actual) {
      return const Success(null);
    }

    final hasCategoryAllocation = transaction.splits.any(
      (split) => split.categoryId != null,
    );

    if (!hasCategoryAllocation) {
      return const Success(null);
    }

    final settingsResult = await _getSettings();

    if (settingsResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final settings = settingsResult.valueOrNull;

    if (settings == null) {
      return const SettingsNotInitializedFailure(
        message: 'Settings have not been initialized.',
      );
    }

    if (settings.allowOverbudgetTransactions) {
      return const Success(null);
    }

    final categoriesResult = await _getCategories();

    if (categoriesResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    final categories = categoriesResult.valueOrNull!;

    final categoriesById = <CategoryId, Category>{
      for (final category in categories) category.id: category,
    };

    final affectedCategoriesResult = _affectedCategories(
      transaction: transaction,
      categoriesById: categoriesById,
    );

    if (affectedCategoriesResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final affectedCategories = affectedCategoriesResult.valueOrNull!;

    final effectiveDate = CalendarDate.fromDateTime(
      transaction.effectiveAt.toUtc(),
    );

    for (final category in affectedCategories) {
      final budget = category.budgetAt(effectiveDate);

      if (budget == null) {
        continue;
      }

      final window = _budgetWindow(
        budget: budget,
        effectiveDate: effectiveDate,
      );

      final transactionsResult = await _queryTransactions(
        TransactionQuery(
          kinds: TransactionKind.values
              .where((kind) => kind.supportsSplits)
              .toSet(),
          states: {TransactionState.actual},
          effectiveFrom: window.from,
          effectiveUntil: window.until,
        ),
      );

      if (transactionsResult case final Failure<TransactionFailure> failure) {
        return failure;
      }

      final existingSpending = _calculateSpending(
        category: category,
        categoriesById: categoriesById,
        valuationCurrencyId: budget.limit.assetId,
        transactions: transactionsResult.valueOrNull!,
      );

      final currentUsage = existingSpending.aggregateSignedValue;

      final previousContribution = _previousContribution(
        previous: previous,
        category: category,
        categoriesById: categoriesById,
        valuationCurrencyId: budget.limit.assetId,
        effectiveFrom: window.from,
        effectiveUntil: window.until,
      );

      final nextContribution = _calculateSpending(
        category: category,
        categoriesById: categoriesById,
        valuationCurrencyId: budget.limit.assetId,
        transactions: [transaction],
      ).aggregateSignedValue;

      final projectedUsage =
          currentUsage - previousContribution + nextContribution;

      final exceedsLimit = projectedUsage > budget.limit.amount;
      final worsensBudget = projectedUsage > currentUsage;

      if (exceedsLimit && worsensBudget) {
        return TransactionWouldExceedBudgetFailure(
          message:
              'Transaction would exceed the budget for category '
              '"${category.name}" (${category.id.value}). '
              'Current usage: $currentUsage. '
              'Projected usage: $projectedUsage. '
              'Budget limit: ${budget.limit.amount}. '
              'Valuation asset: ${budget.limit.assetId.value}.',
        );
      }
    }

    return const Success(null);
  }

  Result<List<Category>, BaseFailure> _affectedCategories({
    required Transaction transaction,
    required Map<CategoryId, Category> categoriesById,
  }) {
    final affected = <CategoryId, Category>{};

    for (final split in transaction.splits) {
      final categoryId = split.categoryId;

      if (categoryId == null) {
        continue;
      }

      final category = categoriesById[categoryId];

      if (category == null) {
        return AllocationCategoryNotFoundFailure(
          message:
              'Transaction allocation references a category that does not '
              'exist: ${categoryId.value}',
        );
      }

      affected[category.id] = category;

      final parentCategoryId = category.parentCategoryId;

      if (parentCategoryId == null) {
        continue;
      }

      final parent = categoriesById[parentCategoryId];

      if (parent == null) {
        return AllocationCategoryNotFoundFailure(
          message:
              'Transaction allocation references a category whose parent '
              'does not exist: ${parentCategoryId.value}',
        );
      }

      affected[parent.id] = parent;
    }

    return Success(List<Category>.unmodifiable(affected.values));
  }

  CategorySpending _calculateSpending({
    required Category category,
    required Map<CategoryId, Category> categoriesById,
    required AssetId valuationCurrencyId,
    required Iterable<Transaction> transactions,
  }) {
    final directAllocationAmounts = <AssetAmount>[];
    final childAllocationAmounts = <AssetAmount>[];

    for (final transaction in transactions) {
      for (final split in transaction.splits) {
        final splitCategoryId = split.categoryId;

        if (splitCategoryId == null) {
          continue;
        }

        if (splitCategoryId == category.id) {
          directAllocationAmounts.add(split.valuationAmount);
          continue;
        }

        if (!category.isTopLevel) {
          continue;
        }

        final splitCategory = categoriesById[splitCategoryId];

        if (splitCategory?.parentCategoryId == category.id) {
          childAllocationAmounts.add(split.valuationAmount);
        }
      }
    }

    return _calculator.calculate(
      categoryId: category.id,
      kind: category.kind,
      valuationCurrencyId: valuationCurrencyId,
      directAllocationAmounts: directAllocationAmounts,
      childAllocationAmounts: childAllocationAmounts,
    );
  }

  Decimal _previousContribution({
    required Transaction? previous,
    required Category category,
    required Map<CategoryId, Category> categoriesById,
    required AssetId valuationCurrencyId,
    required DateTime effectiveFrom,
    required DateTime effectiveUntil,
  }) {
    if (previous == null || previous.state != TransactionState.actual) {
      return Decimal.zero;
    }

    if (!_fallsWithin(
      previous.effectiveAt,
      effectiveFrom: effectiveFrom,
      effectiveUntil: effectiveUntil,
    )) {
      return Decimal.zero;
    }

    return _calculateSpending(
      category: category,
      categoriesById: categoriesById,
      valuationCurrencyId: valuationCurrencyId,
      transactions: [previous],
    ).aggregateSignedValue;
  }

  ({DateTime from, DateTime until}) _budgetWindow({
    required CategoryBudget budget,
    required CalendarDate effectiveDate,
  }) {
    final DateTime calendarFrom;
    final DateTime calendarUntil;

    switch (budget.period) {
      case BudgetPeriod.monthly:
        calendarFrom = DateTime.utc(effectiveDate.year, effectiveDate.month, 1);

        calendarUntil = DateTime.utc(
          effectiveDate.year,
          effectiveDate.month + 1,
          1,
        );

      case BudgetPeriod.yearly:
        calendarFrom = DateTime.utc(effectiveDate.year, 1, 1);

        calendarUntil = DateTime.utc(effectiveDate.year + 1, 1, 1);
    }

    var from = calendarFrom;
    var until = calendarUntil;

    final budgetFrom = budget.effectiveFrom.toDateTimeUtc();

    if (budgetFrom.isAfter(from)) {
      from = budgetFrom;
    }

    final budgetUntil = budget.effectiveUntil?.toDateTimeUtc();

    if (budgetUntil != null && budgetUntil.isBefore(until)) {
      until = budgetUntil;
    }

    return (from: from, until: until);
  }

  bool _fallsWithin(
    DateTime value, {
    required DateTime effectiveFrom,
    required DateTime effectiveUntil,
  }) {
    final utc = value.toUtc();

    return !utc.isBefore(effectiveFrom) && utc.isBefore(effectiveUntil);
  }
}
