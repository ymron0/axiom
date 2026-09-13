import 'package:axiom/src/features/custodians/application/use_cases/update_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_custodian_use_case_provider.g.dart';

/// Provides the use case for updating one custodian.
@riverpod
UpdateCustodianUseCase updateCustodianUseCase(Ref ref) {
  return UpdateCustodianUseCase(ref.watch(custodianRepositoryProvider));
}
