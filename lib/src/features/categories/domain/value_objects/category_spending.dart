import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:decimal/decimal.dart';

/// Derived net activity for one category.
///
/// This value is not persisted. It represents financial activity derived from
/// transaction allocations for a caller-selected period.
///
/// ## Direct versus aggregate totals
///
/// [directTotal] contains the net flow of allocations whose category identifier
/// is exactly [categoryId].
///
/// [aggregateTotal] contains the net flow of:
///
/// - allocations made directly to [categoryId]; and
/// - allocations made to direct child categories when [categoryId] identifies
///   a top-level category.
///
/// For a child category, [aggregateTotal] therefore equals [directTotal].
///
/// ## Direction semantics
///
/// Totals retain their actual net financial direction.
///
/// Incoming allocations increase financial balances and outgoing allocations
/// decrease financial balances. Opposing allocations net against one another.
///
/// Category kind does not constrain the resulting direction.
///
/// Consequently:
///
/// - an expense category normally has an outgoing total;
/// - an expense category may have an incoming total when reimbursements exceed
///   expenses;
/// - an income category normally has an incoming total; and
/// - an income category may have an outgoing total when adjustments exceed
///   income.
///
/// [directSignedValue] and [aggregateSignedValue] expose these totals using the
/// category's own reporting convention:
///
/// - activity matching [kind] is positive;
/// - activity opposing [kind] is negative.
///
/// For example, an expense category whose reimbursements exceed expenses by
/// CHF 50 has an incoming total of CHF 50 and a signed category value of -50.
///
/// ## Currency semantics
///
/// Both totals are expressed in the application's valuation currency.
///
/// Historical transaction allocations are already persisted with their
/// valuation value. They must therefore not be converted again while deriving
/// category activity.
///
/// ## Invariants
///
/// - both totals are known amounts; and
/// - both totals use the same asset.
///
/// No magnitude relationship is required between [directTotal] and
/// [aggregateTotal]. Child activity may reduce or reverse the parent's net
/// total.
final class CategorySpending {
  /// Category whose derived totals are represented.
  final CategoryId categoryId;

  /// Classification and reporting nature of the category.
  final CategoryKind kind;

  /// Net value allocated directly to [categoryId].
  final AssetAmount directTotal;

  /// Net value allocated directly to [categoryId] plus its direct children.
  final AssetAmount aggregateTotal;

  /// Creates derived category activity.
  CategorySpending({
    required this.categoryId,
    required this.kind,
    required this.directTotal,
    required this.aggregateTotal,
  }) {
    _validateKnownAmount(directTotal, 'directTotal');
    _validateKnownAmount(aggregateTotal, 'aggregateTotal');

    if (directTotal.assetId != aggregateTotal.assetId) {
      throw ArgumentError.value(
        aggregateTotal,
        'aggregateTotal',
        'Direct and aggregate category totals must use the same asset.',
      );
    }
  }

  /// Valuation currency in which both totals are expressed.
  AssetId get valuationCurrencyId => directTotal.assetId;

  /// Direct total expressed relative to the category's normal financial kind.
  ///
  /// Positive means activity matching [kind].
  ///
  /// Negative means opposite-direction activity.
  Decimal get directSignedValue => _categorySignedValue(directTotal);

  /// Aggregate total expressed relative to the category's normal financial kind.
  ///
  /// Positive means activity matching [kind].
  ///
  /// Negative means opposite-direction activity.
  Decimal get aggregateSignedValue => _categorySignedValue(aggregateTotal);

  void _validateKnownAmount(AssetAmount amount, String parameterName) {
    if (amount.isUnknownAmount) {
      throw ArgumentError.value(
        amount,
        parameterName,
        'Category totals cannot contain unknown amounts.',
      );
    }
  }

  Decimal _categorySignedValue(AssetAmount amount) {
    if (amount.amount == Decimal.zero) {
      return Decimal.zero;
    }

    final matchesCategoryKind = switch (kind) {
      CategoryKind.expense => amount.isOutgoing,
      CategoryKind.income => amount.isIncoming,
    };

    return matchesCategoryKind ? amount.amount : -amount.amount;
  }
}
