import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Reactive jar queries intended for presentation reads.
final class JarWatchQueries {
  final JarRepository _repository;

  /// Creates reactive jar queries backed by [repository].
  JarWatchQueries(this._repository);

  /// Watches every persisted jar.
  Stream<Result<List<Jar>, JarFailure>> all() {
    return _repository.watchAll();
  }

  /// Watches active jars.
  Stream<Result<List<Jar>, JarFailure>> active() {
    return _repository.watchActive();
  }

  /// Watches archived jars.
  Stream<Result<List<Jar>, JarFailure>> archived() {
    return _repository.watchArchived();
  }

  /// Watches one jar by identity.
  Stream<Result<Jar?, JarFailure>> byId(JarId id) {
    return _repository.watchById(id);
  }
}
