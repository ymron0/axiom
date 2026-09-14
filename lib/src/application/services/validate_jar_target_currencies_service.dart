import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';

/// Validates that jar targets use the configured valuation currency.
///
/// This application service owns the cross-feature rule because [JarTarget]
/// deliberately has no dependency on Settings.
final class ValidateJarTargetCurrenciesService {
  /// Creates a validator backed by the Settings application boundary.
  const ValidateJarTargetCurrenciesService({
    required GetSettingsUseCase getSettings,
  }) : _getSettings = getSettings; // ignore: prefer_initializing_formals

  final GetSettingsUseCase _getSettings;

  /// Validates [targets] against the configured valuation currency.
  ///
  /// Empty targets are valid. Settings lookup failures are propagated
  /// unchanged. Returns [InvalidValuationCurrencyFailure] when a target uses
  /// another asset.
  Future<Result<void, BaseFailure>> call(Iterable<JarTarget> targets) async {
    if (targets.isEmpty) {
      return const Success(null);
    }

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

    for (final target in targets) {
      if (target.amount.assetId != settings.valuationCurrencyId) {
        return InvalidValuationCurrencyFailure(
          message:
              'Jar target currency ${target.amount.assetId.value} must match '
              'the valuation currency ${settings.valuationCurrencyId.value}.',
        );
      }
    }

    return const Success(null);
  }
}
