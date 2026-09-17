import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_spending.dart';
import 'package:decimal/decimal.dart';

/// Calculates category activity from valuation-currency allocation amounts.
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
/// ## Netting semantics
///
/// Incoming and outgoing allocations are both valid for every category kind.
///
/// Incoming allocations contribute a positive balance impact.
///
/// Outgoing allocations contribute a negative balance impact.
///
/// Opposing flows are netted before the resulting [AssetAmount] is created.
///
/// For an expense category, an incoming result means reimbursements or other
/// incoming allocations exceeded outgoing expenses. For an income category, an
/// outgoing result means outgoing adjustments exceeded incoming income.
///
/// [CategoryKind] determines only the deterministic direction used to represent
/// an exact zero:
///
/// - expense category zero is outgoing;
/// - income category zero is incoming.
///
/// This keeps empty-category representation stable without imposing a
/// transaction-direction restriction.
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
/// - must use [valuationCurrencyId]; and
/// - must contain a known amount.
final class CategorySpendingCalculator {
  /// Creates a stateless category spending calculator.
  const CategorySpendingCalculator();

  /// Calculates direct and aggregate net totals for [categoryId].
  CategorySpending calculate({
    required CategoryId categoryId,
    required CategoryKind kind,
    required AssetId valuationCurrencyId,
    required Iterable<AssetAmount> directAllocationAmounts,
    required Iterable<AssetAmount> childAllocationAmounts,
  }) {
    final directSignedAmount = _sumSigned(
      valuationCurrencyId: valuationCurrencyId,
      allocationAmounts: directAllocationAmounts,
    );

    final childSignedAmount = _sumSigned(
      valuationCurrencyId: valuationCurrencyId,
      allocationAmounts: childAllocationAmounts,
    );

    return CategorySpending(
      categoryId: categoryId,
      kind: kind,
      directTotal: _fromSignedAmount(
        kind: kind,
        valuationCurrencyId: valuationCurrencyId,
        signedAmount: directSignedAmount,
      ),
      aggregateTotal: _fromSignedAmount(
        kind: kind,
        valuationCurrencyId: valuationCurrencyId,
        signedAmount: directSignedAmount + childSignedAmount,
      ),
    );
  }

  Decimal _sumSigned({
    required AssetId valuationCurrencyId,
    required Iterable<AssetAmount> allocationAmounts,
  }) {
    var total = Decimal.zero;

    for (final allocationAmount in allocationAmounts) {
      _validateAllocation(
        valuationCurrencyId: valuationCurrencyId,
        allocationAmount: allocationAmount,
      );

      total += allocationAmount.isIncoming
          ? allocationAmount.amount
          : -allocationAmount.amount;
    }

    return total;
  }

  void _validateAllocation({
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
  }

  AssetAmount _fromSignedAmount({
    required CategoryKind kind,
    required AssetId valuationCurrencyId,
    required Decimal signedAmount,
  }) {
    if (signedAmount > Decimal.zero) {
      return AssetAmount.incoming(
        assetId: valuationCurrencyId,
        amount: signedAmount,
      );
    }

    if (signedAmount < Decimal.zero) {
      return AssetAmount.outgoing(
        assetId: valuationCurrencyId,
        amount: signedAmount.abs(),
      );
    }

    return switch (kind) {
      CategoryKind.expense => AssetAmount.outgoing(
        assetId: valuationCurrencyId,
        amount: Decimal.zero,
      ),
      CategoryKind.income => AssetAmount.incoming(
        assetId: valuationCurrencyId,
        amount: Decimal.zero,
      ),
    };
  }
}