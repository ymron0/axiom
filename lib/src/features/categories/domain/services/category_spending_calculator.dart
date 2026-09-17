import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_spending.dart';
import 'package:decimal/decimal.dart';

/// Calculates category spending from valuation-currency allocation amounts.
///
/// The caller owns:
///
/// - resolving the category;
/// - selecting the requested transaction period;
/// - excluding non-actual transactions;
/// - determining which allocations belong directly to the category;
/// - determining which allocations belong to direct child categories; and
/// - resolving the application's valuation currency.
///
/// This calculator owns only deterministic monetary aggregation.
///
/// ## Semantics
///
/// Expense categories aggregate outgoing valuation amounts.
///
/// Income categories aggregate incoming valuation amounts.
///
/// The resulting amount is a magnitude. Expense totals are therefore returned
/// as outgoing [AssetAmount] values rather than as negative [Decimal] values.
///
/// [CategorySpending.directTotal] contains only [directAllocationAmounts].
///
/// [CategorySpending.aggregateTotal] contains both
/// [directAllocationAmounts] and [childAllocationAmounts].
///
/// ## Currency handling
///
/// Every allocation must already use [valuationCurrencyId].
///
/// No exchange-rate lookup or conversion occurs here. Historical transaction
/// valuation amounts must not be revalued.
///
/// ## Invariants
///
/// Every supplied allocation:
///
/// - must use [valuationCurrencyId];
/// - must contain a known amount; and
/// - must have the direction implied by [kind].
final class CategorySpendingCalculator {
  /// Creates a stateless category spending calculator.
  const CategorySpendingCalculator();

  /// Calculates direct and aggregate totals for [categoryId].
  CategorySpending calculate({
    required CategoryId categoryId,
    required CategoryKind kind,
    required AssetId valuationCurrencyId,
    required Iterable<AssetAmount> directAllocationAmounts,
    required Iterable<AssetAmount> childAllocationAmounts,
  }) {
    final directAmount = _sum(
      kind: kind,
      valuationCurrencyId: valuationCurrencyId,
      allocationAmounts: directAllocationAmounts,
    );

    final childAmount = _sum(
      kind: kind,
      valuationCurrencyId: valuationCurrencyId,
      allocationAmounts: childAllocationAmounts,
    );

    final directTotal = _amount(
      kind: kind,
      valuationCurrencyId: valuationCurrencyId,
      amount: directAmount,
    );

    final aggregateTotal = _amount(
      kind: kind,
      valuationCurrencyId: valuationCurrencyId,
      amount: directAmount + childAmount,
    );

    return CategorySpending(
      categoryId: categoryId,
      kind: kind,
      directTotal: directTotal,
      aggregateTotal: aggregateTotal,
    );
  }

  Decimal _sum({
    required CategoryKind kind,
    required AssetId valuationCurrencyId,
    required Iterable<AssetAmount> allocationAmounts,
  }) {
    var total = Decimal.zero;

    for (final allocationAmount in allocationAmounts) {
      _validateAllocation(
        kind: kind,
        valuationCurrencyId: valuationCurrencyId,
        allocationAmount: allocationAmount,
      );

      total += allocationAmount.amount;
    }

    return total;
  }

  void _validateAllocation({
    required CategoryKind kind,
    required AssetId valuationCurrencyId,
    required AssetAmount allocationAmount,
  }) {
    if (allocationAmount.assetId != valuationCurrencyId) {
      throw ArgumentError.value(
        allocationAmount.assetId,
        'allocationAmounts',
        'Every category allocation must use the valuation currency.',
      );
    }

    if (allocationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        allocationAmount,
        'allocationAmounts',
        'Category allocations cannot contain unknown valuation amounts.',
      );
    }

    final hasExpectedDirection = switch (kind) {
      CategoryKind.expense => allocationAmount.isOutgoing,
      CategoryKind.income => allocationAmount.isIncoming,
    };

    if (!hasExpectedDirection) {
      throw ArgumentError.value(
        allocationAmount,
        'allocationAmounts',
        'Category allocation direction must match the category kind.',
      );
    }
  }

  AssetAmount _amount({
    required CategoryKind kind,
    required AssetId valuationCurrencyId,
    required Decimal amount,
  }) {
    return switch (kind) {
      CategoryKind.expense => AssetAmount.outgoing(
        assetId: valuationCurrencyId,
        amount: amount,
      ),
      CategoryKind.income => AssetAmount.incoming(
        assetId: valuationCurrencyId,
        amount: amount,
      ),
    };
  }
}
