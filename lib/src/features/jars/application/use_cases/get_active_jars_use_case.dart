import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Returns persisted jars that are not archived.
final class GetActiveJarsUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  GetActiveJarsUseCase(this._repository);

  /// Returns every unarchived persisted jar.
  Future<Result<List<Jar>, JarFailure>> call() {
    return _repository.getActive();
  }
}
