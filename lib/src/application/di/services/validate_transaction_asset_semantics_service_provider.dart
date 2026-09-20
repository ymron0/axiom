import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/features/assets/di/get_assets_by_ids_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_transaction_asset_semantics_service_provider.g.dart';

/// Provides cross-feature transaction Asset validation.
@riverpod
ValidateTransactionAssetSemanticsService
validateTransactionAssetSemanticsService(Ref ref) {
  return ValidateTransactionAssetSemanticsService(
    getAssetsByIds: ref.watch(getAssetsByIdsUseCaseProvider),
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
  );
}
