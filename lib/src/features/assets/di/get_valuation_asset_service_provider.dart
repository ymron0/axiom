import 'package:axiom/src/features/assets/application/services/get_valuation_asset_service.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_valuation_asset_service_provider.g.dart';

/// Provides the service that resolves the configured valuation asset.
@riverpod
GetValuationAssetService getValuationAssetService(Ref ref) {
  return GetValuationAssetService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getAssetById: ref.watch(getAssetByIdUseCaseProvider),
  );
}
