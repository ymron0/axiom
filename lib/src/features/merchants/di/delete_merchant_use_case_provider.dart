import 'package:axiom/src/features/merchants/application/use_cases/delete_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_merchant_use_case_provider.g.dart';

/// Provides the use case for deleting one merchant.
@riverpod
DeleteMerchantUseCase deleteMerchantUseCase(Ref ref) {
  return DeleteMerchantUseCase(ref.watch(merchantRepositoryProvider));
}
