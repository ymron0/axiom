import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/merchants/application/use_cases/create_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_merchant_use_case_provider.g.dart';

/// Provides the use case for creating one merchant.
@riverpod
CreateMerchantUseCase createMerchantUseCase(Ref ref) {
  return CreateMerchantUseCase(
    repository: ref.watch(merchantRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
