import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_custodians_use_case_provider.g.dart';

/// Provides the use case for retrieving all custodians.
@riverpod
GetCustodiansUseCase getCustodiansUseCase(Ref ref) {
  return GetCustodiansUseCase(ref.watch(custodianRepositoryProvider));
}
