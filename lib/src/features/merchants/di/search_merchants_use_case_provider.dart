import 'package:axiom/src/features/merchants/application/use_cases/search_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_merchants_use_case_provider.g.dart';

/// Provides the use case for searching merchants.
@riverpod
SearchMerchantsUseCase searchMerchantsUseCase(Ref ref) {
  return SearchMerchantsUseCase(ref.watch(merchantRepositoryProvider));
}
