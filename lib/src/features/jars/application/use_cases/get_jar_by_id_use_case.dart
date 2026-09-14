import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Returns a jar by identity.
class GetJarByIdUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  GetJarByIdUseCase(this._repository);

  /// Returns the jar identified by [id], or `null` when absent.
  Future<Result<Jar?, JarFailure>> call(JarId id) {
    return _repository.getById(id);
  }
}
