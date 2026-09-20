import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'asset_valuation_service_provider.g.dart';

/// Provides asset valuation into the configured fiat valuation currency.
@riverpod
AssetValuationService assetValuationService(Ref ref) {
  return AssetValuationService(
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
    resolveConversionRate: ref.watch(resolveConversionRateServiceProvider),
    calculator: const AssetValuationCalculator(),
  );
}
