import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings.mapper.dart';

/// General application settings.
///
/// The valuation currency is the common monetary reference used for
/// cross-asset values, totals, summaries, budgets, and other valuation-based
/// amounts.
///
/// Budget enforcement is configurable independently from the category budget
/// definitions themselves.
///
/// ## Overbudget transaction semantics
///
/// [allowOverbudgetTransactions] determines whether an actual transaction may
/// worsen a category budget beyond its configured limit.
///
/// When `true`, category budgets are informational and transactions may exceed
/// their limits.
///
/// When `false`, transaction creation and update workflows reject financial
/// changes that would worsen an applicable category budget beyond its limit.
///
/// The default is `true` so existing behavior remains permissive unless the
/// user explicitly enables strict budget enforcement.
///
/// ## Invariants
///
/// - [valuationCurrencyId] is required.
/// - [valuationCurrencyId] must resolve to an existing Currency in the
///   application level.
/// - Other Asset subtypes are invalid valuation currencies.
///
/// ## Semantics
///
/// The valuation currency does not constrain the currencies used by accounts
/// or transactions, and it does not convert or duplicate currency data. It is
/// the single application-wide monetary reference.
///
/// Once initial setup has completed, normal settings operations must preserve
/// the valuation currency. Changing it requires an application reset.
@MappableClass()
class Settings with SettingsMappable {
  /// Creates application settings.
  const Settings({
    required this.valuationCurrencyId,
    this.allowOverbudgetTransactions = true,
  });

  /// Identifier of the currency used as the application's valuation currency.
  final AssetId valuationCurrencyId;

  /// Whether transactions may worsen category spending beyond budget limits.
  ///
  /// `true` means overbudget transactions are allowed.
  ///
  /// `false` means actual transaction workflows reject changes that would
  /// worsen an applicable budget beyond its configured limit.
  final bool allowOverbudgetTransactions;
}
