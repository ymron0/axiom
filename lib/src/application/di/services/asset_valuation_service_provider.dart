import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'asset_valuation_service_provider.g.dart';

/// Provides the service that values asset amounts in the configured
/// valuation currency.
///
/// Feature-owned dependencies are resolved through their public DI providers.
///
/// The stateless [AssetValuationCalculator] is constructed locally because it
/// owns only deterministic domain arithmetic and has no external dependencies.
@riverpod
AssetValuationService assetValuationService(Ref ref) {
  return AssetValuationService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    resolveConversionRate: ref.watch(resolveConversionRateServiceProvider),
    calculator: const AssetValuationCalculator(),
  );
}
