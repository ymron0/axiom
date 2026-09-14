import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Performs the feature-local physical deletion of a jar.
///
/// Cross-feature transaction usage checks must be performed before invoking
/// this use case.
class DeleteJarUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  DeleteJarUseCase(this._repository);

  /// Physically deletes the jar identified by [id].
  Future<Result<Jar, JarFailure>> call(JarId id) {
    return _repository.delete(id);
  }
}
