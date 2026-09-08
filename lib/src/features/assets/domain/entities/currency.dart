part of 'asset.dart';

/// A currency represented as an asset, such as EUR, CHF, or USD.
///
/// Example:
/// ```dart
/// final euro = Currency(
///   id: AssetId.generate(),
///   name: 'Euro',
///   code: AssetCode('EUR'),
///   symbol: '€',
///   decimalPlaces: 2,
/// );
/// ```
@MappableClass()
final class Currency extends Asset with CurrencyMappable {
  /// Creates a currency.
  ///
  /// Throws [ArgumentError] when [code] does not contain exactly three ASCII
  /// letters.
  Currency({
    required super.id,
    required super.name,
    required super.code,
    super.symbol,
    super.remoteLogoUrl,
    super.bundledLogoAsset,
    required super.decimalPlaces,
  }) {
    final codeValue = code.value;
    final isThreeLetterCode = RegExp(r'^[A-Za-z]{3}$').hasMatch(code.value);

    if (!isThreeLetterCode) {
      throw ArgumentError.value(
        codeValue,
        'code',
        'Currency code must contain exactly three letters',
      );
    }
  }
}
