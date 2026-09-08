import 'package:axiom/src/core/domain/validation/url_validation.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'currency.dart';
part 'asset.mapper.dart';

/// Base class for assets.
///
/// Concrete assets should extend this entity and provide the required
/// identifying and display metadata. Example:
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

  /// The human-readable name of the asset, e.g., 'Euro'.
  final String name;

  /// The code used to identify the asset, e.g. 'EUR'.
  final AssetCode code;

  /// An optional short symbol shown to users, e.g., '€'.
  final String? symbol;

  /// The number of fractional decimal places supported by the asset.
  final int decimalPlaces;

  /// An optional remote logo URL, e.g., 'https://example.com/euro.png'.
  final String? remoteLogoUrl;

  /// An optional path to a bundled logo asset, e.g., 'assets/logos/euro.png'.
  final String? bundledLogoAsset;

  /// Creates an asset with its identity and display metadata.
  ///
  /// Trims [name] and [symbol] when supplied.
  ///
  /// Throws [ArgumentError] when [name], [symbol], or [bundledLogoAsset] is
  /// blank, when [remoteLogoUrl] is not an absolute HTTP(S) URL, or when
  /// [decimalPlaces] is outside the range 0 to 18.
  Asset({
    required this.id,
    required String name,
    required this.code,
    String? symbol,
    required this.decimalPlaces,
    String? remoteLogoUrl,
    String? bundledLogoAsset,
  }) : name = _requireNonBlank(name, 'name'),
       symbol = _normalizeOptionalText(symbol, 'symbol'),
       remoteLogoUrl = _normalizeOptionalUrl(remoteLogoUrl),
       bundledLogoAsset = _normalizeOptionalText(
         bundledLogoAsset,
         'bundledLogoAsset',
       ) {
    if (decimalPlaces < 0 || decimalPlaces > 18) {
      throw ArgumentError.value(
        decimalPlaces,
        'decimalPlaces',
        'Decimal places must be between 0 and 18',
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

// Trims optional text and rejects a supplied blank value.
String? _normalizeOptionalText(String? value, String name) {
  if (value == null) {
    return null;
  }

  return _requireNonBlank(value, name);
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
