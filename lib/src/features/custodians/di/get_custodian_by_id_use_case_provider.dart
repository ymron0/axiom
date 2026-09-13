import 'package:axiom/src/features/custodians/application/use_cases/get_custodian_by_id_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_custodian_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving a custodian by identifier.
@riverpod
GetCustodianByIdUseCase getCustodianByIdUseCase(Ref ref) {
  return GetCustodianByIdUseCase(ref.watch(custodianRepositoryProvider));
}
