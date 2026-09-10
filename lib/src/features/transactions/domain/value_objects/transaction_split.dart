import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/budget_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_split.mapper.dart';

/// Allocates part of a transaction's value to the app's allocation targets.
///
/// A split describes how transaction value is classified or allocated. It does
/// not describe movement into or out of an account; account balance impact is
/// represented separately by `LedgerEntry`.
///
/// A single split may reference multiple allocation dimensions. For example,
/// an expense may simultaneously belong to a budget and a category.
///
/// ## Invariants
///
/// - [transactionAmount] and [valuationAmount] obey the invariants enforced by
///   [AssetAmount].
/// - Both amounts have the same direction.
/// - When both amounts use the same asset, their quantities are identical.
/// - At least one allocation target must be specified.
/// - Asset, direction, and total reconciliation against the corresponding
///   ledger amounts are validated by the owning transaction aggregate.
///
/// ## Semantics
///
/// [budgetId], [categoryId], and [jarId] identify independent allocation
/// dimensions. Their presence does not multiply the monetary value represented
/// by [transactionAmount] or [valuationAmount].
///
/// The complete collection of transaction splits must reconcile exactly with
/// both the transaction amount and its valuation according to the owning
/// transaction's aggregate rules.
///
/// ## Contract
///
/// This value object validates only invariants that can be determined from one
/// split in isolation. Cross-split and transaction-level invariants belong to
/// the transaction aggregate.
@MappableClass()
final class TransactionSplit with TransactionSplitMappable {
  /// The portion allocated by this split in the transaction's currency.
  final AssetAmount transactionAmount;

  /// The value of [transactionAmount] in Axiom's valuation currency.
  ///
  /// This is the same allocation as [transactionAmount] expressed
  /// in another currency, not an additional allocation.
  final AssetAmount valuationAmount;

  /// The budget receiving this allocation, when applicable.
  final BudgetId? budgetId;

  /// The category receiving this allocation, when applicable.
  final CategoryId? categoryId;

  /// The jar receiving this allocation, when applicable.
  final JarId? jarId;

  /// Creates a transaction split.
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - no allocation target is specified;
  /// - the amounts have different directions; or
  /// - the amounts use the same asset but have different quantities.
  TransactionSplit({
    required this.transactionAmount,
    required this.valuationAmount,
    this.budgetId,
    this.categoryId,
    this.jarId,
  }) {
    if (budgetId == null && categoryId == null && jarId == null) {
      throw ArgumentError(
        'A transaction split must specify at least one allocation target.',
      );
    }

    if (transactionAmount.direction != valuationAmount.direction) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Valuation amount must have the same direction as the transaction '
            'amount.',
      );
    }

    final usesSameAsset = transactionAmount.assetId == valuationAmount.assetId;

    if (usesSameAsset && transactionAmount.amount != valuationAmount.amount) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Transaction and valuation amounts must be equal when they use the '
            'same asset.',
      );
    }
  }
}
