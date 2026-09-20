import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset.mapper.dart';
part 'commodity_asset.dart';
part 'crypto_asset.dart';
part 'currency.dart';
part 'stock_asset.dart';

/// Base domain model for an identifiable financial asset.
///
/// An [Asset] owns metadata common to supported asset classes while keeping
/// identity separate from display metadata and financial behavior. Concrete
/// assets extend this type and define subtype-specific invariants.
///
/// ## Invariants
///
/// - [id] is a valid, strongly typed [AssetId].
/// - [entityVersion] is greater than zero.
/// - [modifiedAt] does not precede [createdAt].
/// - [name] is non-blank after trimming.
/// - [code] is a valid [AssetCode].
/// - [decimalPlaces] is non-negative.
/// - [logo] is either `null` or a valid [EntityLogo].
/// - [paymentEnabled] follows the concrete subtype's payment semantics.
///
/// ## Payment semantics
///
/// Currency assets are always payment enabled.
///
/// Crypto assets decide their payment capability explicitly and default to
/// disabled.
///
/// Stocks and commodities can never be used directly as payment assets.
///
/// ## Contract
///
/// Subclasses must preserve the immutable asset state established here and
/// keep subtype-specific financial rules in the subtype. This type has no
/// persistence, repository, or presentation responsibilities.
@MappableClass()
sealed class Asset extends AuditedEntity<AssetId> with AssetMappable {
  /// The trimmed human-readable name of the asset.
  final String name;

  /// The code used to identify the asset.
  final AssetCode code;

  /// An optional short symbol shown to users.
  final String? symbol;

  /// The number of fractional decimal places supported by the asset.
  final int decimalPlaces;

  /// An optional logo associated with the asset.
  final EntityLogo? logo;

  /// Creates the shared asset state.
  ///
  /// Trims [name] and [symbol] when supplied.
  ///
  /// Throws [ArgumentError] when required text is blank, when supplied
  /// optional text is blank, or when [decimalPlaces] is negative.
  Asset({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
    required String name,
    required this.code,
    String? symbol,
    required this.decimalPlaces,
    this.logo,
  }) : name = normalizeRequiredText(name, 'name'),
       symbol = normalizeOptionalText(symbol, 'symbol') {
    if (decimalPlaces < 0) {
      throw ArgumentError.value(
        decimalPlaces,
        'decimalPlaces',
        'Decimal places cannot be negative',
      );
    }
  }

  /// Creates a new currency asset.
  ///
  /// This factory is retained for compatibility with the existing asset
  /// creation application flow. New subtype-aware creation should use the
  /// concrete subtype factories directly.
  ///
  /// The asset starts at entity version `1`.
  factory Asset.create({
    required String name,
    required AssetCode code,
    String? symbol,
    EntityLogo? logo,
    required int decimalPlaces,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Currency(
      id: AssetId.generate(),
      entityVersion: 1,
      createdAt: now,
      modifiedAt: now,
      name: name,
      code: code,
      symbol: symbol,
      logo: logo,
      decimalPlaces: decimalPlaces,
    );
  }

  /// Whether this asset can be used directly for payments.
  ///
  /// The concrete subtype owns this rule.
  bool get paymentEnabled;
}
