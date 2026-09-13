import 'package:axiom/src/features/custodians/application/use_cases/search_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_custodians_use_case_provider.g.dart';

/// Provides the use case for searching custodians.
@riverpod
SearchCustodiansUseCase searchCustodiansUseCase(Ref ref) {
  return SearchCustodiansUseCase(ref.watch(custodianRepositoryProvider));
}
