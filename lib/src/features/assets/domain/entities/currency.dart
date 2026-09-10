part of 'asset.dart';

/// A fiat currency represented as an [Asset], such as EUR, CHF, or USD.
///
/// [Currency] is a distinct subtype even though it currently shares the
/// structural metadata of [Asset]. The subtype establishes fiat-money
/// semantics and provides a boundary for future currency-specific behavior
/// without placing those rules on assets such as cryptocurrencies, stocks,
/// metals, or funds.
///
/// [Currency] inherits the validation and identity semantics of [Asset] and
/// additionally requires a three-letter ASCII currency code.
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
  /// Inherits the validation contract of [Asset]. Throws [ArgumentError] when
  /// [code] does not contain exactly three ASCII letters.
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
