import 'package:axiom/src/features/jars/application/use_cases/get_active_jars_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_active_jars_use_case_provider.g.dart';

/// Provides the use case for retrieving active jars.
@riverpod
GetActiveJarsUseCase getActiveJarsUseCase(Ref ref) {
  return GetActiveJarsUseCase(ref.watch(jarRepositoryProvider));
}
