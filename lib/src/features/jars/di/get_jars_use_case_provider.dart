import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_jars_use_case_provider.g.dart';

/// Provides the use case for retrieving all jars.
@riverpod
GetJarsUseCase getJarsUseCase(Ref ref) {
  return GetJarsUseCase(ref.watch(jarRepositoryProvider));
}
