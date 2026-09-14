import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Returns jars having a requested financial kind.
final class GetJarsByKindUseCase {
  final JarRepository _repository;

  /// Creates a use case backed by [repository].
  GetJarsByKindUseCase(this._repository);

  /// Returns every persisted jar having [kind].
  ///
  /// Archived jars are included.
  Future<Result<List<Jar>, JarFailure>> call(JarKind kind) {
    return _repository.getByKind(kind);
  }
}
