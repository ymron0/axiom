import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_state.g.dart';

/// Complete data required by the settings screen.
///
/// Uninitialized settings are represented by `settings == null`.
///
/// This is a valid application state after a reset and is therefore not
/// represented as a failure.
final class SettingsScreenData {
  /// Creates settings-screen presentation data.
  const SettingsScreenData({
    required this.settings,
    required this.valuationCurrency,
  });

  /// Persisted settings, or `null` before initialization.
  final Settings? settings;

  /// Resolved valuation currency.
  ///
  /// This is `null` exactly when [settings] is `null`.
  final Currency? valuationCurrency;

  /// Whether initial settings have been configured.
  bool get isInitialized => settings != null;
}

/// Loads the settings screen state.
///
/// The valuation currency is resolved through the existing application service
/// so the presentation layer cannot accidentally accept a non-currency asset.
@riverpod
Future<Result<SettingsScreenData, BaseFailure>> settingsScreenData(
  Ref ref,
) async {
  final settingsResult = await ref.watch(getSettingsUseCaseProvider)();

  if (settingsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final settings = settingsResult.valueOrNull;

  if (settings == null) {
    return const Success(
      SettingsScreenData(settings: null, valuationCurrency: null),
    );
  }

  final currencyResult = await ref.watch(getValuationCurrencyServiceProvider)();

  if (currencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    SettingsScreenData(
      settings: settings,
      valuationCurrency: currencyResult.valueOrNull!,
    ),
  );
}

/// Loads currencies that may be selected during settings initialization.
///
/// Filtering occurs by concrete domain type rather than presentation metadata.
@riverpod
Future<Result<List<Currency>, BaseFailure>> valuationCurrencyOptions(
  Ref ref,
) async {
  final result = await ref.watch(getAssetUseCaseProvider)();

  if (result case final Failure<BaseFailure> failure) {
    return failure;
  }

  final currencies = result.valueOrNull!.whereType<Currency>().toList(
    growable: false,
  )..sort((left, right) => left.code.value.compareTo(right.code.value));

  return Success(List.unmodifiable(currencies));
}
