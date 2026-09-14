import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Restores a caller-retained physically deleted jar snapshot.
final class RestoreJarUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  RestoreJarUseCase(this._repository);

  /// Restores [jar] to persistence.
  ///
  /// The original archival state is preserved.
  Future<Result<void, JarFailure>> call(Jar jar) {
    if (!jar.isDeleted) {
      return Future.value(
        JarNotDeletedFailure(message: 'Jar is not deleted: ${jar.id.value}'),
      );
    }

    return _repository.restore(jar);
  }
}
