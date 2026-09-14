import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Archives a persisted jar without deleting it.
final class ArchiveJarUseCase {
  final JarRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const ArchiveJarUseCase({
    required JarRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Archives the jar identified by [id].
  ///
  /// Existing transaction references do not prevent archival.
  Future<Result<Jar, JarFailure>> call(JarId id) {
    return _repository.archive(id, _clock.nowUtc);
  }
}
