import 'package:axiom/src/features/merchants/application/use_cases/get_active_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_active_merchants_use_case_provider.g.dart';

/// Provides the use case for retrieving active merchants.
@riverpod
GetActiveMerchantsUseCase getActiveMerchantsUseCase(Ref ref) {
  return GetActiveMerchantsUseCase(ref.watch(merchantRepositoryProvider));
}
