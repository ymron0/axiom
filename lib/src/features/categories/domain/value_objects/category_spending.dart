import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';

/// Derived spending or received-value totals for one category.
///
/// This value is not persisted. It represents financial activity derived from
/// transaction allocations for a caller-selected period.
///
/// ## Direct versus aggregate totals
///
/// [directTotal] contains only allocations whose category identifier is exactly
/// [categoryId].
///
/// [aggregateTotal] contains:
///
/// - [directTotal]; and
/// - allocations belonging to direct child categories when [categoryId]
///   identifies a top-level category.
///
/// For a child category, [aggregateTotal] therefore equals [directTotal].
///
/// ## Direction semantics
///
/// Category totals retain the financial direction implied by [kind]:
///
/// - expense categories use outgoing amounts;
/// - income categories use incoming amounts.
///
/// The quantity itself remains a non-negative [AssetAmount] magnitude.
///
/// ## Currency semantics
///
/// Both totals are expressed in the application's valuation currency.
///
/// Historical transaction allocations are already persisted with their
/// valuation value. They must therefore not be converted again while deriving
/// category spending.
///
/// ## Invariants
///
/// - both totals are known amounts;
/// - both totals use the same asset;
/// - both totals use the direction required by [kind];
/// - [aggregateTotal] cannot be smaller than [directTotal].
final class CategorySpending {
  /// Category whose derived totals are represented.
  final CategoryId categoryId;

  /// Financial nature of the category.
  final CategoryKind kind;

  /// Total allocated directly to [categoryId].
  final AssetAmount directTotal;

  /// Total allocated directly to [categoryId] plus its direct children.
  final AssetAmount aggregateTotal;

  /// Creates derived category spending.
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

    _validateDirection(directTotal, 'directTotal');
    _validateDirection(aggregateTotal, 'aggregateTotal');

    if (aggregateTotal.amount < directTotal.amount) {
      throw ArgumentError.value(
        aggregateTotal,
        'aggregateTotal',
        'Aggregate category total cannot be smaller than the direct total.',
      );
    }
  }

  /// Valuation currency in which both totals are expressed.
  AssetId get valuationCurrencyId => directTotal.assetId;

  void _validateKnownAmount(AssetAmount amount, String parameterName) {
    if (amount.isUnknownAmount) {
      throw ArgumentError.value(
        amount,
        parameterName,
        'Category spending totals cannot contain unknown amounts.',
      );
    }
  }

  void _validateDirection(AssetAmount amount, String parameterName) {
    final hasExpectedDirection = switch (kind) {
      CategoryKind.expense => amount.isOutgoing,
      CategoryKind.income => amount.isIncoming,
    };

    if (!hasExpectedDirection) {
      throw ArgumentError.value(
        amount,
        parameterName,
        'Category spending total direction must match the category kind.',
      );
    }
  }
}
