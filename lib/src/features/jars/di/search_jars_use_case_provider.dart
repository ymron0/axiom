import 'package:axiom/src/features/jars/application/use_cases/search_jars_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_jars_use_case_provider.g.dart';

/// Provides the use case for searching jars.
@riverpod
SearchJarsUseCase searchJarsUseCase(Ref ref) {
  return SearchJarsUseCase(ref.watch(jarRepositoryProvider));
}
