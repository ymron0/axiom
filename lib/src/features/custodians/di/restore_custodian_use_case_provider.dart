import 'package:axiom/src/features/custodians/application/use_cases/restore_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_custodian_use_case_provider.g.dart';

/// Provides the use case for restoring one custodian.
@riverpod
RestoreCustodianUseCase restoreCustodianUseCase(Ref ref) {
  return RestoreCustodianUseCase(ref.watch(custodianRepositoryProvider));
}
