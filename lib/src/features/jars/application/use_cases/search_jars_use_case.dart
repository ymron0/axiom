import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Searches persisted jars by name.
final class SearchJarsUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  SearchJarsUseCase(this._repository);

  /// Returns jars whose names contain [query].
  Future<Result<List<Jar>, JarFailure>> call(String query) {
    return _repository.search(query);
  }
}
