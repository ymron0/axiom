import 'package:axiom/src/features/jars/application/use_cases/get_archived_jars_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_archived_jars_use_case_provider.g.dart';

/// Provides the use case for retrieving archived jars.
@riverpod
GetArchivedJarsUseCase getArchivedJarsUseCase(Ref ref) {
  return GetArchivedJarsUseCase(ref.watch(jarRepositoryProvider));
}
