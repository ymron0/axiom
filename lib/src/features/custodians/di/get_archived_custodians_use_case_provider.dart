import 'package:axiom/src/features/custodians/application/use_cases/get_archived_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_archived_custodians_use_case_provider.g.dart';

/// Provides the use case for retrieving archived custodians.
@riverpod
GetArchivedCustodiansUseCase getArchivedCustodiansUseCase(Ref ref) {
  return GetArchivedCustodiansUseCase(ref.watch(custodianRepositoryProvider));
}
