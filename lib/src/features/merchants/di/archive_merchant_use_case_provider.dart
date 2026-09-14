import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/merchants/application/use_cases/archive_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_merchant_use_case_provider.g.dart';

/// Provides the use case for archiving a merchant.
@riverpod
ArchiveMerchantUseCase archiveMerchantUseCase(Ref ref) {
  return ArchiveMerchantUseCase(
    repository: ref.watch(merchantRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
