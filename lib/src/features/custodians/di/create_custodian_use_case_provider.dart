import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/custodians/application/use_cases/create_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_custodian_use_case_provider.g.dart';

/// Provides the use case for creating one custodian.
@riverpod
CreateCustodianUseCase createCustodianUseCase(Ref ref) {
  return CreateCustodianUseCase(
    repository: ref.watch(custodianRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
