import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/custodians/application/use_cases/unarchive_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unarchive_custodian_use_case_provider.g.dart';

/// Provides the use case for unarchiving one custodian.
@riverpod
UnarchiveCustodianUseCase unarchiveCustodianUseCase(Ref ref) {
  return UnarchiveCustodianUseCase(
    repository: ref.watch(custodianRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
