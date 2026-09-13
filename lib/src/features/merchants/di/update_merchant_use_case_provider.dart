import 'package:axiom/src/features/merchants/application/use_cases/update_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_merchant_use_case_provider.g.dart';

/// Provides the use case for updating one merchant.
@riverpod
UpdateMerchantUseCase updateMerchantUseCase(Ref ref) {
  return UpdateMerchantUseCase(ref.watch(merchantRepositoryProvider));
}
