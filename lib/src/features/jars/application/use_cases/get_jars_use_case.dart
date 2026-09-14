import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Returns all persisted jars, including archived jars.
final class GetJarsUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  GetJarsUseCase(this._repository);

  /// Returns all persisted jars.
  Future<Result<List<Jar>, JarFailure>> call() {
    return _repository.getAll();
  }
}
