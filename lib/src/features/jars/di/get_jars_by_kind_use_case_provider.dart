import 'package:axiom/src/features/jars/application/use_cases/get_jars_by_kind_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_jars_by_kind_use_case_provider.g.dart';

/// Provides the use case for retrieving jars by financial kind.
@riverpod
GetJarsByKindUseCase getJarsByKindUseCase(Ref ref) {
  return GetJarsByKindUseCase(ref.watch(jarRepositoryProvider));
}
