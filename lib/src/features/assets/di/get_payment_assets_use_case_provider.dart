import 'package:axiom/src/features/assets/application/use_cases/get_payment_assets_use_case.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_payment_assets_use_case_provider.g.dart';

/// Provides the query returning payment-enabled assets.
@riverpod
GetPaymentAssetsUseCase getPaymentAssetsUseCase(Ref ref) {
  return GetPaymentAssetsUseCase(ref.watch(assetRepositoryProvider));
}
