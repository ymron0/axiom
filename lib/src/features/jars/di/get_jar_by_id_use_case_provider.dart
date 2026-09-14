import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_jar_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving a jar by identity.
@riverpod
GetJarByIdUseCase getJarByIdUseCase(Ref ref) {
  return GetJarByIdUseCase(ref.watch(jarRepositoryProvider));
}
