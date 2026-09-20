import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_jar_target_currencies_service_provider.g.dart';

/// Provides Jar target valuation-currency validation.
@riverpod
ValidateJarTargetCurrenciesService validateJarTargetCurrenciesService(Ref ref) {
  return ValidateJarTargetCurrenciesService(
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
  );
}
