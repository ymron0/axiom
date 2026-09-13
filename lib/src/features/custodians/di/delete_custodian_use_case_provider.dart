import 'package:axiom/src/features/custodians/application/use_cases/delete_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_custodian_use_case_provider.g.dart';

/// Provides the use case for deleting one custodian.
@riverpod
DeleteCustodianUseCase deleteCustodianUseCase(Ref ref) {
  return DeleteCustodianUseCase(ref.watch(custodianRepositoryProvider));
}
