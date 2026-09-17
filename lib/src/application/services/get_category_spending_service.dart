import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_spending.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';

/// Derives category spending for a requested transaction period.
///
/// This service coordinates:
///
/// - Categories, to resolve the requested category and its direct children;
/// - Settings, to resolve the valuation currency;
/// - Transactions, to retrieve actual financial activity for the period; and
/// - [CategorySpendingCalculator], to perform monetary aggregation.
///
/// ## Period semantics
///
/// [effectiveFrom] is inclusive.
///
/// [effectiveUntil] is exclusive.
///
/// Both values are normalized to UTC before querying transactions.
///
/// An empty period where both boundaries are equal is valid and produces zero
/// totals when the transaction query returns no rows.
///
/// ## Transaction semantics
///
/// Only actual transactions participate.
///
/// Expense categories query expense transactions.
///
/// Income categories query income transactions.
///
/// Planned transactions are excluded because category spending represents
/// realized financial activity rather than forecast activity.
///
/// ## Hierarchy semantics
///
/// A child category counts only allocations made directly to itself.
///
/// For a top-level category:
///
/// - `directTotal` counts allocations made directly to that category;
/// - `aggregateTotal` additionally counts allocations made to its direct
///   children.
///
/// Archived children remain relevant because their historical allocations still
/// contributed to the parent category while those transactions were effective.
///
/// The Categories domain supports only one child level, so recursive hierarchy
/// traversal is not required.
///
/// ## Currency semantics
///
/// Transaction splits already persist their value in the application's
/// valuation currency through `TransactionSplit.valuationAmount`.
///
/// Historical allocations are therefore aggregated directly. This service does
/// not perform exchange-rate lookup or revalue an old transaction using a newer
/// rate.
///
/// ## Failure semantics
///
/// Returns:
///
/// - [CategorySpending] on success;
/// - [CategoryNotFoundFailure] when [categoryId] cannot be resolved;
/// - [SettingsNotInitializedFailure] when settings do not exist; or
/// - failures propagated unchanged from the underlying feature use cases.
///
/// Invalid monetary data reaching [CategorySpendingCalculator] is a violated
/// domain invariant and is surfaced as [ArgumentError].
final class GetCategorySpendingService {
  final GetCategoryByIdUseCase _getCategoryById;
  final GetCategoriesUseCase _getCategories;
  final GetSettingsUseCase _getSettings;
  final QueryTransactionsUseCase _queryTransactions;
  final CategorySpendingCalculator _calculator;

  /// Creates a category spending service.
  const GetCategorySpendingService({
    required GetCategoryByIdUseCase getCategoryById,
    required GetCategoriesUseCase getCategories,
    required GetSettingsUseCase getSettings,
    required QueryTransactionsUseCase queryTransactions,
    required CategorySpendingCalculator calculator,
  }) : _getCategoryById = // ignore: prefer_initializing_formals
           getCategoryById,
       _getCategories = // ignore: prefer_initializing_formals
           getCategories,
       _getSettings = // ignore: prefer_initializing_formals
           getSettings,
       _queryTransactions = // ignore: prefer_initializing_formals
           queryTransactions,
       _calculator = // ignore: prefer_initializing_formals
           calculator;

  /// Derives category spending for `[effectiveFrom, effectiveUntil)`.
  Future<Result<CategorySpending, BaseFailure>> call(
    CategoryId categoryId, {
    required DateTime effectiveFrom,
    required DateTime effectiveUntil,
  }) async {
    final effectiveFromUtc = effectiveFrom.toUtc();
    final effectiveUntilUtc = effectiveUntil.toUtc();

    if (effectiveUntilUtc.isBefore(effectiveFromUtc)) {
      throw ArgumentError.value(
        effectiveUntil,
        'effectiveUntil',
        'Category spending end time cannot precede its start time.',
      );
    }

    final categoryResult = await _getCategoryById(categoryId);

    if (categoryResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    final category = categoryResult.valueOrNull;

    if (category == null) {
      return CategoryNotFoundFailure(
        message: 'Category ID was not found: ${categoryId.value}',
      );
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

    final childCategoryIds = <CategoryId>{};

    if (category.isTopLevel) {
      final categoriesResult = await _getCategories();

      if (categoriesResult case final Failure<CategoryFailure> failure) {
        return failure;
      }

      for (final candidate in categoriesResult.valueOrNull!) {
        if (candidate.parentCategoryId == category.id) {
          childCategoryIds.add(candidate.id);
        }
      }
    }

    final query = TransactionQuery(
      kinds: {_transactionKindFor(category.kind)},
      states: {TransactionState.actual},
      effectiveFrom: effectiveFromUtc,
      effectiveUntil: effectiveUntilUtc,
    );

    final transactionsResult = await _queryTransactions(query);

    if (transactionsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final directAllocationAmounts = <AssetAmount>[];
    final childAllocationAmounts = <AssetAmount>[];

    for (final transaction in transactionsResult.valueOrNull!) {
      for (final split in transaction.splits) {
        final splitCategoryId = split.categoryId;

        if (splitCategoryId == category.id) {
          directAllocationAmounts.add(split.valuationAmount);
          continue;
        }

        if (splitCategoryId != null &&
            childCategoryIds.contains(splitCategoryId)) {
          childAllocationAmounts.add(split.valuationAmount);
        }
      }
    }

    return Success(
      _calculator.calculate(
        categoryId: category.id,
        kind: category.kind,
        valuationCurrencyId: settings.valuationCurrencyId,
        directAllocationAmounts: directAllocationAmounts,
        childAllocationAmounts: childAllocationAmounts,
      ),
    );
  }

  TransactionKind _transactionKindFor(CategoryKind categoryKind) {
    return switch (categoryKind) {
      CategoryKind.expense => TransactionKind.expense,
      CategoryKind.income => TransactionKind.income,
    };
  }
}
