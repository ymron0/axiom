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
final class Currency extends Asset with CurrencyMappable {
  /// Creates a currency.
  ///
  /// Inherits the validation contract of [Asset]. Throws [ArgumentError] when
  /// [code] does not contain exactly three ASCII letters.
  Currency({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
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

  /// Creates a currency with a generated identity and audit timestamps.
  ///
  /// The generated currency starts at entity version `1`. The supplied clock
  /// is sampled once in UTC and the resulting timestamp is used for both
  /// [createdAt] and [modifiedAt]. Throws [ArgumentError] when [code] does
  /// not contain exactly three ASCII letters.
  Currency.generate({
    required String name,
    required AssetCode code,
    String? symbol,
    String? remoteLogoUrl,
    String? bundledLogoAsset,
    required int decimalPlaces,
    Clock clock = const SystemClock(),
  }) : this._generated(
         name: name,
         code: code,
         symbol: symbol,
         remoteLogoUrl: remoteLogoUrl,
         bundledLogoAsset: bundledLogoAsset,
         decimalPlaces: decimalPlaces,
         generatedAt: clock.nowUtc,
       );

  Currency._generated({
    required String name,
    required AssetCode code,
    String? symbol,
    String? remoteLogoUrl,
    String? bundledLogoAsset,
    required int decimalPlaces,
    required DateTime generatedAt,
  }) : this(
         id: AssetId.generate(),
         entityVersion: 1,
         createdAt: generatedAt,
         modifiedAt: generatedAt,
         name: name,
         code: code,
         symbol: symbol,
         remoteLogoUrl: remoteLogoUrl,
         bundledLogoAsset: bundledLogoAsset,
         decimalPlaces: decimalPlaces,
       );
}
