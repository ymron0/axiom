import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:decimal/decimal.dart';

/// Performs conversion calculations between asset rates.
///
/// This service contains only domain-level rate mathematics. It does not
/// retrieve rates, access repositories, or know how rates are persisted.
///
/// Persisted rates are quoted against USD, but that is a persistence
/// rule rather than a restriction on calculations performed by this service.
///
/// ## Semantics
///
/// Given persisted rates:
///
/// ```text
/// EUR/USD = 1.18
/// CHF/USD = 1.26
/// ```
///
/// the cross rate is:
///
/// ```text
/// EUR/CHF = (EUR/USD) / (CHF/USD)
///         = 1.18 / 1.26
/// ```
///
/// Inversion is calculated as:
///
/// ```text
/// USD/EUR = 1 / (EUR/USD)
/// ```
///
/// ## Contract
///
/// All supplied rates must use the expected asset orientation. This service
/// validates asset identities before performing a calculation.
final class RateConversionService {
  /// Creates a rate conversion service.
  const RateConversionService();

  /// Returns the inverse value of [rate].
  ///
  /// For:
  ///
  /// ```text
  /// EUR/USD = 1.18
  /// ```
  ///
  /// this returns:
  ///
  /// ```text
  /// USD/EUR = 1 / 1.18
  /// ```
  Decimal invert(Rate rate) {
    return rate.rate.inverse.toDecimal(scaleOnInfinitePrecision: 18);
  }

  /// Calculates the cross-rate value between two assets through [bridgeAssetId].
  ///
  /// Both [baseBridgeRate] and [quoteBridgeRate] must be quoted in
  /// [bridgeAssetId].
  ///
  /// For example:
  ///
  /// ```text
  /// baseBridgeRate  = EUR/USD
  /// quoteBridgeRate = CHF/USD
  /// bridgeAssetId   = USD
  ///
  /// EUR/CHF = EUR/USD / CHF/USD
  /// ```
  Decimal cross({
    required Rate baseBridgeRate,
    required Rate quoteBridgeRate,
    required AssetId bridgeAssetId,
  }) {
    _validateBridgeRate(
      rate: baseBridgeRate,
      bridgeAssetId: bridgeAssetId,
      parameterName: 'baseBridgeRate',
    );

    _validateBridgeRate(
      rate: quoteBridgeRate,
      bridgeAssetId: bridgeAssetId,
      parameterName: 'quoteBridgeRate',
    );

    if (baseBridgeRate.baseAssetId == quoteBridgeRate.baseAssetId) {
      return Decimal.one;
    }

    return (baseBridgeRate.rate / quoteBridgeRate.rate).toDecimal(
      scaleOnInfinitePrecision: 18,
    );
  }

  /// Resolves the conversion value for [baseAssetId]/[quoteAssetId].
  ///
  /// [baseBridgeRate] is required when [baseAssetId] is not the bridge asset.
  /// [quoteBridgeRate] is required when [quoteAssetId] is not the bridge asset.
  ///
  /// The supported cases are:
  ///
  /// ```text
  /// A/A       = 1
  /// A/bridge  = A/bridge
  /// bridge/B  = 1 / (B/bridge)
  /// A/B       = (A/bridge) / (B/bridge)
  /// ```
  Decimal resolve({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required AssetId bridgeAssetId,
    Rate? baseBridgeRate,
    Rate? quoteBridgeRate,
  }) {
    if (baseAssetId == quoteAssetId) {
      return Decimal.one;
    }

    if (quoteAssetId == bridgeAssetId) {
      final rate = baseBridgeRate;

      if (rate == null) {
        throw ArgumentError.notNull('baseBridgeRate');
      }

      _validateRatePair(
        rate: rate,
        baseAssetId: baseAssetId,
        quoteAssetId: bridgeAssetId,
        parameterName: 'baseBridgeRate',
      );

      return rate.rate;
    }

    if (baseAssetId == bridgeAssetId) {
      final rate = quoteBridgeRate;

      if (rate == null) {
        throw ArgumentError.notNull('quoteBridgeRate');
      }

      _validateRatePair(
        rate: rate,
        baseAssetId: quoteAssetId,
        quoteAssetId: bridgeAssetId,
        parameterName: 'quoteBridgeRate',
      );

      return invert(rate);
    }

    final baseRate = baseBridgeRate;
    final quoteRate = quoteBridgeRate;

    if (baseRate == null) {
      throw ArgumentError.notNull('baseBridgeRate');
    }

    if (quoteRate == null) {
      throw ArgumentError.notNull('quoteBridgeRate');
    }

    _validateRatePair(
      rate: baseRate,
      baseAssetId: baseAssetId,
      quoteAssetId: bridgeAssetId,
      parameterName: 'baseBridgeRate',
    );

    _validateRatePair(
      rate: quoteRate,
      baseAssetId: quoteAssetId,
      quoteAssetId: bridgeAssetId,
      parameterName: 'quoteBridgeRate',
    );

    return cross(
      baseBridgeRate: baseRate,
      quoteBridgeRate: quoteRate,
      bridgeAssetId: bridgeAssetId,
    );
  }

  void _validateBridgeRate({
    required Rate rate,
    required AssetId bridgeAssetId,
    required String parameterName,
  }) {
    if (rate.quoteAssetId != bridgeAssetId) {
      throw ArgumentError.value(
        rate.quoteAssetId,
        parameterName,
        'Rate must be quoted in the bridge asset.',
      );
    }
  }

  void _validateRatePair({
    required Rate rate,
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required String parameterName,
  }) {
    if (rate.baseAssetId != baseAssetId || rate.quoteAssetId != quoteAssetId) {
      throw ArgumentError.value(
        rate,
        parameterName,
        'Expected rate $baseAssetId/$quoteAssetId.',
      );
    }
  }
}
