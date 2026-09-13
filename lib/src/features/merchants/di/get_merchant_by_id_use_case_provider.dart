import 'package:axiom/src/features/merchants/application/use_cases/get_merchant_by_id_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_merchant_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving a merchant by identifier.
@riverpod
GetMerchantByIdUseCase getMerchantByIdUseCase(Ref ref) {
  return GetMerchantByIdUseCase(ref.watch(merchantRepositoryProvider));
}
