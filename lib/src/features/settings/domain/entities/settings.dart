import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings.mapper.dart';

/// General application settings.
///
/// The valuation currency is the common monetary reference used for
/// cross-asset values, totals, summaries, budgets, and other valuation-based
/// amounts. The selected currency is referenced by ID rather than embedded in
/// this object because settings store the relationship to the asset; the
/// asset repository remains responsible for resolving the ID to its domain
/// entity.
///
/// ## Invariants
///
/// - [valuationCurrencyId] is required.
/// - [valuationCurrencyId] must resolve to an existing [Currency] 
/// in the application level.
/// - Other [Asset] subtypes are invalid valuation currencies.
///
/// ## Semantics
///
/// The valuation currency does not constrain the currencies used by accounts
/// or transactions, and it does not convert or duplicate currency data. It is
/// the single application-wide monetary reference. The field remains typed as
/// [AssetId] because asset IDs identify all asset subtypes; the narrower
/// currency constraint is validated by the initial-settings workflow after
/// resolving the ID through [AssetRepository].
///
/// Once initial setup has completed, normal settings operations cannot replace
/// the valuation currency. Changing it requires an application reset.
///
/// ## Contract
///
/// Constructing this value stores the reference only. Callers creating the
/// initial settings must use the application workflow that validates the
/// referenced asset before persisting this object.
@MappableClass()
class Settings with SettingsMappable {
  const Settings({required this.valuationCurrencyId});

  /// Identifier of the currency used as the application's valuation currency.
  final AssetId valuationCurrencyId;
}
