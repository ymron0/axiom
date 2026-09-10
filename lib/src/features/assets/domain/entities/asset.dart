import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/validation/url_validation.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
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
/// persistence, repository, or presentation responsibilities.
///
/// Example:
/// ```dart
/// final asset = Currency(
///   id: AssetId.generate(),
///   name: 'Euro',
///   code: AssetCode('EUR'),
///   symbol: '€',
///   decimalPlaces: 2,
/// );
/// ```
@MappableClass()
sealed class Asset with AssetMappable {
  /// The typed identifier of the asset.
  final AssetId id;

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
    required this.id,
    required String name,
    required this.code,
    String? symbol,
    required this.decimalPlaces,
    String? remoteLogoUrl,
    String? bundledLogoAsset,
  }) : name = _requireNonBlank(name, 'name'),
       symbol = normalizeOptionalText(symbol, 'symbol'),
       remoteLogoUrl = _normalizeOptionalUrl(remoteLogoUrl),
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

// Trims text and rejects blank values for required or optional fields.
String _requireNonBlank(String value, String name) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, '$name cannot be blank');
  }

  return normalized;
}

// Trims an optional URL and accepts only absolute HTTP(S) URLs with a host.
String? _normalizeOptionalUrl(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = _requireNonBlank(value, 'remoteLogoUrl');

  if (!isValidHttpUrl(normalized)) {
    throw ArgumentError.value(
      value,
      'remoteLogoUrl',
      'Remote logo URL must be an absolute HTTP(S) URL',
    );
  }

  return normalized;
}
