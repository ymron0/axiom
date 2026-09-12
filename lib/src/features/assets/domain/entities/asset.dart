import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/validation/url_validation.dart';
import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/system_clock.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'currency.dart';
part 'asset.mapper.dart';

/// Base domain model for an identifiable financial asset.
///
/// An [Asset] owns metadata common to supported asset classes while keeping
/// identity separate from display metadata and financial behavior. Concrete
/// assets should extend this type and add only subtype-specific invariants and
/// behavior.
///
/// ## Invariants
///
/// - [id] is a valid, strongly typed [AssetId].
/// - [entityVersion] is greater than zero.
/// - [modifiedAt] does not precede [createdAt].
/// - [name] is non-blank after trimming.
/// - [code] is a valid [AssetCode].
/// - [decimalPlaces] is non-negative.
/// - Optional metadata is either `null` or a valid non-blank value.
/// - Asset identity is represented by [id], independently of display metadata.
///
/// ## Semantics
///
/// [Asset] is the common parent for financial asset types such as currencies,
/// blockchain assets, stocks, metals, and funds. [name], [code], [symbol], and
/// logo metadata describe an asset; they do not define its identity.
///
/// ## Contract
///
/// Subclasses must preserve the immutable asset state established here and
/// must keep subtype-specific financial rules in the subtype. This type has no
/// persistence, repository, or presentation responsibilities. Audit metadata
/// follows the [AuditedEntity] contract.
///
/// Example:
/// ```dart
/// final asset = Currency(
///   id: AssetId.generate(),
///   entityVersion: 1,
///   createdAt: DateTime.utc(2024, 1, 1),
///   modifiedAt: DateTime.utc(2024, 1, 1),
///   name: 'Euro',
///   code: AssetCode('EUR'),
///   symbol: '€',
///   decimalPlaces: 2,
/// );
/// ```
@MappableClass()
sealed class Asset extends AuditedEntity<AssetId> with AssetMappable {
  /// The trimmed human-readable name of the asset, e.g., 'Euro'.
  final String name;

  /// The code used to identify the asset, e.g. 'EUR'.
  final AssetCode code;

  /// An optional short symbol shown to users, e.g., '€'.
  final String? symbol;

  /// The number of fractional decimal places supported by the asset.
  final int decimalPlaces;

  /// An optional absolute HTTP(S) URL for the asset logo.
  final String? remoteLogoUrl;

  /// An optional path to a bundled logo asset.
  final String? bundledLogoAsset;

  /// Creates an asset with its identity and display metadata.
  ///
  /// Trims [name], [symbol], and optional logo metadata when supplied.
  ///
  /// Throws [ArgumentError] when required text is blank, when supplied optional
  /// text is blank, when [remoteLogoUrl] is not an absolute HTTP(S) URL, or
  /// when [decimalPlaces] is negative.
  Asset({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
    required String name,
    required this.code,
    String? symbol,
    required this.decimalPlaces,
    String? remoteLogoUrl,
    String? bundledLogoAsset,
    }) : name = normalizeRequiredText(name, 'name'),
       symbol = normalizeOptionalText(symbol, 'symbol'),
      remoteLogoUrl = normalizeOptionalHttpUrl(remoteLogoUrl, 'remoteLogoUrl'),
       bundledLogoAsset = normalizeOptionalText(
         bundledLogoAsset,
         'bundledLogoAsset',
       ) {
    if (decimalPlaces < 0) {
      throw ArgumentError.value(
        decimalPlaces,
        'decimalPlaces',
        'Decimal places cannot be negative',
      );
    }
  }
}
