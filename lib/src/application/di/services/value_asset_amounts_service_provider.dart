import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'value_asset_amounts_service_provider.g.dart';

/// Provides valuation of multiple asset balances into one target asset.
@riverpod
ValueAssetAmountsService valueAssetAmountsService(Ref ref) {
  return ValueAssetAmountsService(
    resolveConversionRate: ref.watch(resolveConversionRateServiceProvider),
    calculator: const AssetValuationCalculator(),
  );
}
