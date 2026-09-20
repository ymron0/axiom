import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_valuation_currency_service_provider.g.dart';

/// Provides the application boundary for resolving the valuation Currency.
@riverpod
GetValuationCurrencyService getValuationCurrencyService(Ref ref) {
  return GetValuationCurrencyService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getAssetById: ref.watch(getAssetByIdUseCaseProvider),
  );
}
