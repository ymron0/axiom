import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Restores an archived jar to normal active use.
final class UnarchiveJarUseCase {
  final JarRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const UnarchiveJarUseCase({
    required JarRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Unarchives the jar identified by [id].
  Future<Result<Jar, JarFailure>> call(JarId id) {
    return _repository.unarchive(id, _clock.nowUtc);
  }
}
