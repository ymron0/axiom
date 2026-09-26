import 'package:axiom/src/core/presentation/formatting/app_number_formatter.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// Formats asset quantities for presentation.
///
/// This formatter composes the shared locale-aware number infrastructure with
/// Assets feature metadata such as code, symbol, and decimal precision.
///
/// ## Invariants
///
/// The supplied [Asset] must identify the same asset as the [AssetAmount] being
/// formatted.
///
/// ## Semantics
///
/// Unknown amounts are represented using [unknownValue].
///
/// Direction may optionally be represented as an explicit localized sign.
///
/// Generic quantities use the asset's display symbol when available, otherwise
/// its canonical code.
///
/// Currency formatting uses the locale's currency pattern.
///
/// ## Contract
///
/// Asset mismatch is a programmer/application composition error and therefore
/// throws [ArgumentError] rather than returning a recoverable formatting
/// failure.
///
/// Invalid user-entered numeric text is handled separately by
/// `AppNumberFormatter.parseDecimal`.
final class AssetAmountFormatter {
  /// Number formatter used for locale-sensitive rendering.
  final AppNumberFormatter numbers;

  /// Text shown when an amount is unknown.
  final String unknownValue;

  /// Creates an asset amount formatter.
  const AssetAmountFormatter({required this.numbers, this.unknownValue = '—'});

  /// Formats an asset quantity.
  ///
  /// Example output may resemble `12.500 BTC` or `12,500 BTC`, depending on
  /// locale.
  String quantity(
    AssetAmount amount,
    Asset asset, {
    bool includeUnit = true,
    bool includeDirectionSign = false,
  }) {
    _verifyAsset(amount, asset);

    if (amount.isUnknownAmount) {
      return unknownValue;
    }

    final formatted = numbers.fixedDecimal(
      amount.amount,
      fractionDigits: asset.decimalPlaces,
    );

    final signed = includeDirectionSign
        ? _withDirection(formatted, amount)
        : formatted;

    if (!includeUnit) {
      return signed;
    }

    final unit = asset.symbol ?? asset.code.value;

    return '$signed\u00A0$unit';
  }

  /// Formats an amount as a monetary currency value.
  ///
  /// This method requires a [Currency] because locale currency formatting is
  /// semantically different from displaying units of stocks, commodities, or
  /// cryptocurrencies.
  String currency(
    AssetAmount amount,
    Currency currency, {
    bool includeDirectionSign = false,
  }) {
    _verifyAsset(amount, currency);

    if (amount.isUnknownAmount) {
      return unknownValue;
    }

    final signedAmount = _signedAmount(amount);

    final formatted = numbers.currency(
      signedAmount,
      currencyCode: currency.code.value,
      symbol: currency.symbol,
      decimalDigits: currency.decimalPlaces,
    );

    if (!includeDirectionSign || amount.isOutgoing) {
      return formatted;
    }

    return '${numbers.plusSign}$formatted';
  }

  Decimal _signedAmount(AssetAmount amount) {
    return amount.isOutgoing ? -amount.amount : amount.amount;
  }

  String _withDirection(String formatted, AssetAmount amount) {
    if (amount.isOutgoing) {
      return '${numbers.minusSign}$formatted';
    }

    return '${numbers.plusSign}$formatted';
  }

  void _verifyAsset(AssetAmount amount, Asset asset) {
    if (amount.assetId != asset.id) {
      throw ArgumentError.value(
        asset.id,
        'asset',
        'The asset does not match the amount being formatted.',
      );
    }
  }
}
