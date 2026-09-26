import 'package:axiom/src/core/presentation/formatting/formatting_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

/// Locale-aware formatter for presentation numeric values.
///
/// Decimal values are formatted through `DecimalFormatter`, avoiding conversion
/// to binary floating-point values.
///
/// ## Invariants
///
/// [localeName] identifies the locale used by every formatting operation
/// performed by this instance.
///
/// ## Semantics
///
/// Formatting valid numeric values is deterministic.
///
/// Parsing is an input-boundary operation and therefore returns a typed
/// [FormattingFailure] when the input cannot be interpreted.
///
/// ## Contract
///
/// This formatter contains no feature-specific financial semantics. Asset,
/// currency, transaction, and budget formatting build on this primitive.
final class AppNumberFormatter {
  /// Canonical locale used for formatting.
  final String localeName;

  /// Creates a locale-aware number formatter.
  AppNumberFormatter({required String localeName})
    : localeName = Intl.canonicalizedLocale(localeName);

  /// Formats [value] using locale-aware decimal separators and grouping.
  ///
  /// [minimumFractionDigits] controls trailing zero preservation.
  ///
  /// [maximumFractionDigits] controls the maximum displayed precision.
  String decimal(
    Decimal value, {
    int minimumFractionDigits = 0,
    int? maximumFractionDigits,
  }) {
    if (minimumFractionDigits < 0) {
      throw ArgumentError.value(
        minimumFractionDigits,
        'minimumFractionDigits',
        'Minimum fraction digits cannot be negative.',
      );
    }

    if (maximumFractionDigits != null &&
        maximumFractionDigits < minimumFractionDigits) {
      throw ArgumentError.value(
        maximumFractionDigits,
        'maximumFractionDigits',
        'Maximum fraction digits cannot be less than the minimum.',
      );
    }

    final format = NumberFormat.decimalPattern(localeName)
      ..minimumFractionDigits = minimumFractionDigits
      ..maximumFractionDigits = maximumFractionDigits ?? value.scale;

    return DecimalFormatter(format).format(value);
  }

  /// Formats [value] with exactly [fractionDigits] decimal places.
  String fixedDecimal(Decimal value, {required int fractionDigits}) {
    if (fractionDigits < 0) {
      throw ArgumentError.value(
        fractionDigits,
        'fractionDigits',
        'Fraction digits cannot be negative.',
      );
    }

    final format = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: fractionDigits,
    );

    return DecimalFormatter(format).format(value);
  }

  /// Formats a ratio as a locale-aware percentage.
  ///
  /// A value of `0.125` represents `12.5%`.
  String percentage(Decimal ratio, {int decimalDigits = 0}) {
    if (decimalDigits < 0) {
      throw ArgumentError.value(
        decimalDigits,
        'decimalDigits',
        'Decimal digits cannot be negative.',
      );
    }

    final format = NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: decimalDigits,
    );

    return DecimalFormatter(format).format(ratio);
  }

  /// Formats a decimal value using the locale's currency pattern.
  ///
  /// The caller supplies the currency semantics so this shared formatter does
  /// not depend on the Assets feature.
  String currency(
    Decimal value, {
    required String currencyCode,
    required int decimalDigits,
    String? symbol,
  }) {
    if (currencyCode.trim().isEmpty) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Currency code cannot be blank.',
      );
    }

    if (decimalDigits < 0) {
      throw ArgumentError.value(
        decimalDigits,
        'decimalDigits',
        'Decimal digits cannot be negative.',
      );
    }

    final format = NumberFormat.currency(
      locale: localeName,
      name: currencyCode,
      symbol: symbol ?? currencyCode,
      decimalDigits: decimalDigits,
    );

    return DecimalFormatter(format).format(value);
  }

  /// Parses locale-aware decimal input.
  ///
  /// Returns a typed failure instead of throwing when user input cannot be
  /// interpreted.
  Result<Decimal, FormattingFailure> parseDecimal(String input) {
    final normalized = input.trim();

    if (normalized.isEmpty) {
      return const FormattingFailure(message: 'Enter a number.');
    }

    final format = DecimalFormatter(NumberFormat.decimalPattern(localeName));

    final parsed = format.tryParse(normalized);

    if (parsed == null) {
      return const FormattingFailure();
    }

    return Success(parsed);
  }

  /// Parses locale-aware percentage input and returns the represented ratio.
  ///
  /// For example, a localized `12.5%` value returns approximately `0.125`
  /// represented as [Decimal].
  Result<Decimal, FormattingFailure> parsePercentage(String input) {
    final normalized = input.trim();

    if (normalized.isEmpty) {
      return const FormattingFailure(message: 'Enter a percentage.');
    }

    final format = DecimalFormatter(NumberFormat.percentPattern(localeName));

    final parsed = format.tryParse(normalized);

    if (parsed == null) {
      return const FormattingFailure(message: 'Enter a valid percentage.');
    }

    return Success(parsed);
  }

  /// Locale-specific positive sign.
  String get plusSign {
    return NumberFormat.decimalPattern(localeName).symbols.PLUS_SIGN;
  }

  /// Locale-specific negative sign.
  String get minusSign {
    return NumberFormat.decimalPattern(localeName).symbols.MINUS_SIGN;
  }
}
