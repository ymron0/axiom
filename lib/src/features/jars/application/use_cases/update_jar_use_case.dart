import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Replaces one persisted jar snapshot.
final class UpdateJarUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  UpdateJarUseCase(this._repository);

  /// Persists [jar] as the complete new snapshot.
  ///
  /// Archived jars may still be updated.
  Future<Result<void, JarFailure>> call(Jar jar) {
    if (jar.isDeleted) {
      return Future.value(
        JarAlreadyDeletedFailure(
          message: 'Deleted jar cannot be updated: ${jar.id.value}',
        ),
      );
    }

    return _repository.update(jar);
  }
}
