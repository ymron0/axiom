import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:decimal/decimal.dart';

/// Values asset quantities in the application's configured valuation currency.
///
/// This application service coordinates Settings, Rates, and Assets without
/// moving cross-feature responsibilities into any feature-domain entity.
///
/// ## Workflow
///
/// For each valuation:
///
/// 1. retrieve the configured valuation currency from Settings;
/// 2. determine whether a conversion rate is economically required;
/// 3. resolve the source-to-valuation conversion rate when required; and
/// 4. delegate deterministic arithmetic to [AssetValuationCalculator].
///
/// ## Rate lookup
///
/// A rate is required only for a known, non-zero amount whose asset differs
/// from the configured valuation currency.
///
/// Rate lookup is deliberately skipped for:
///
/// - identity valuation;
/// - zero amounts; and
/// - unknown amounts.
///
/// This prevents a zero balance, for example, from becoming unavailable merely
/// because no market observation exists for an asset that currently contributes
/// no value.
///
/// ## Failure semantics
///
/// Failures returned by Settings or rate resolution are propagated unchanged.
///
/// When Settings have not yet been initialized, the service returns
/// [SettingsNotInitializedFailure].
///
/// Malformed calculation inputs are programmer/domain-integrity errors and are
/// therefore rejected by [AssetValuationCalculator] with [ArgumentError]
/// rather than translated into persistence/application failures.
final class AssetValuationService {
  final GetSettingsUseCase _getSettings;
  final ResolveConversionRateService _resolveConversionRate;
  final AssetValuationCalculator _calculator;

  /// Creates the asset valuation service.
  const AssetValuationService({
    required GetSettingsUseCase getSettings,
    required ResolveConversionRateService resolveConversionRate,
    required AssetValuationCalculator calculator,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _resolveConversionRate = // ignore: prefer_initializing_formals
           resolveConversionRate,
       _calculator = calculator; // ignore: prefer_initializing_formals

  /// Values [amount] using the configured valuation currency at [at].
  ///
  /// [at] is forwarded unchanged to rate resolution so historical valuation
  /// uses the same effective-time semantics as the Rates feature.
  Future<Result<AssetAmount, BaseFailure>> call({
    required AssetAmount amount,
    required DateTime at,
  }) async {
    final settingsResult = await _getSettings();

    if (settingsResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final settings = settingsResult.valueOrNull;

    if (settings == null) {
      return const SettingsNotInitializedFailure(
        message: 'Settings have not been initialized.',
      );
    }

    final valuationCurrencyId = settings.valuationCurrencyId;

    final requiresConversionRate =
        amount.assetId != valuationCurrencyId &&
        amount.isKnownAmount &&
        amount.amount != Decimal.zero;

    if (!requiresConversionRate) {
      return Success(
        _calculator.calculate(
          amount: amount,
          valuationCurrencyId: valuationCurrencyId,
        ),
      );
    }

    final rateResult = await _resolveConversionRate(
      fromAssetId: amount.assetId,
      toAssetId: valuationCurrencyId,
      at: at,
    );

    return rateResult.when<Result<AssetAmount, BaseFailure>>(
      success: (conversionRate) => Success(
        _calculator.calculate(
          amount: amount,
          valuationCurrencyId: valuationCurrencyId,
          conversionRate: conversionRate,
        ),
      ),
      failure: (failure) => failure,
    );
  }
}
