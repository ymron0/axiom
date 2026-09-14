import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Returns persisted jars that are archived.
final class GetArchivedJarsUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  GetArchivedJarsUseCase(this._repository);

  /// Returns every archived persisted jar.
  Future<Result<List<Jar>, JarFailure>> call() {
    return _repository.getArchived();
  }
}
