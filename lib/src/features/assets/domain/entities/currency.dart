part of 'asset.dart';

/// A fiat currency represented as an [Asset], such as EUR, CHF, or USD.
///
/// Currency assets are always eligible for payments. This is a type invariant:
/// callers cannot disable payment support for a [Currency].
///
/// [Currency] additionally requires a three-letter ASCII currency code.
@MappableClass()
final class Currency extends Asset with CurrencyMappable {
  /// Creates a currency.
  ///
  /// Inherits the validation contract of [Asset].
  ///
  /// Throws [ArgumentError] when [code] does not contain exactly three ASCII
  /// letters.
  Currency({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
  }) {
    final codeValue = code.value;
    final isThreeLetterCode = RegExp(r'^[A-Za-z]{3}$').hasMatch(codeValue);

    if (!isThreeLetterCode) {
      throw ArgumentError.value(
        codeValue,
        'code',
        'Currency code must contain exactly three letters',
      );
    }
  }

  /// Creates a currency with generated identity and audit timestamps.
  factory Currency.create({
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

  /// Whether this currency can be used for payments.
  ///
  /// Fiat currencies are always payment enabled.
  @override
  bool get paymentEnabled => true;
}