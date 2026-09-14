import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Stores jars in memory.
///
/// Deleted jars are physically absent from [_jars]. Archived jars remain stored
/// and retain their archival metadata.
final class InMemoryJarRepositoryImpl implements JarRepository {
  /// Creates a repository seeded with [initialJars].
  ///
  /// The seed may contain archived jars but cannot contain deleted jars or
  /// duplicate identities.
  InMemoryJarRepositoryImpl({Iterable<Jar> initialJars = const <Jar>[]})
    : _jars = _validatedSeed(initialJars);

  final Map<JarId, Jar> _jars;

  @override
  Future<Result<void, JarFailure>> create(Jar jar) async {
    if (jar.isDeleted) {
      return JarAlreadyDeletedFailure(
        message: 'Deleted jar cannot be created: ${jar.id.value}',
      );
    }

    if (jar.isArchived) {
      return JarAlreadyArchivedFailure(
        message: 'Archived jar cannot be created as a new jar: ${jar.id.value}',
      );
    }

    if (_jars.containsKey(jar.id)) {
      return JarAlreadyExistsFailure(
        message: 'Jar ID already exists: ${jar.id.value}',
      );
    }

    _jars[jar.id] = jar;

    return const Success(null);
  }

  @override
  Future<Result<List<Jar>, JarFailure>> getAll() async {
    return Success(List.unmodifiable(_jars.values));
  }

  @override
  Future<Result<List<Jar>, JarFailure>> getActive() async {
    return Success(_matchingJars((jar) => !jar.isArchived));
  }

  @override
  Future<Result<List<Jar>, JarFailure>> getArchived() async {
    return Success(_matchingJars((jar) => jar.isArchived));
  }

  @override
  Future<Result<Jar?, JarFailure>> getById(JarId id) async {
    return Success(_jars[id]);
  }

  @override
  Future<Result<List<Jar>, JarFailure>> getByKind(JarKind kind) async {
    return Success(_matchingJars((jar) => jar.kind == kind));
  }

  @override
  Future<Result<List<Jar>, JarFailure>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();

    return Success(
      _matchingJars((jar) => jar.name.toLowerCase().contains(normalizedQuery)),
    );
  }

  @override
  Future<Result<void, JarFailure>> update(Jar jar) async {
    if (jar.isDeleted) {
      return JarAlreadyDeletedFailure(
        message: 'Deleted jar cannot be updated: ${jar.id.value}',
      );
    }

    if (!_jars.containsKey(jar.id)) {
      return _notFound(jar.id);
    }

    _jars[jar.id] = jar;

    return const Success(null);
  }

  @override
  Future<Result<Jar, JarFailure>> archive(JarId id, DateTime archivedAt) async {
    final jar = _jars[id];

    if (jar == null) {
      return _notFound(id);
    }

    if (jar.isArchived) {
      return JarAlreadyArchivedFailure(
        message: 'Jar is already archived: ${id.value}',
      );
    }

    final archivedJar = _withArchivedAt(
      jar,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );

    _jars[id] = archivedJar;

    return Success(archivedJar);
  }

  @override
  Future<Result<Jar, JarFailure>> unarchive(
    JarId id,
    DateTime modifiedAt,
  ) async {
    final jar = _jars[id];

    if (jar == null) {
      return _notFound(id);
    }

    if (!jar.isArchived) {
      return JarNotArchivedFailure(message: 'Jar is not archived: ${id.value}');
    }

    final unarchivedJar = _withArchivedAt(
      jar,
      archivedAt: null,
      modifiedAt: modifiedAt,
    );

    _jars[id] = unarchivedJar;

    return Success(unarchivedJar);
  }

  @override
  Future<Result<Jar, JarFailure>> delete(JarId id) async {
    final jar = _jars.remove(id);

    if (jar == null) {
      return _notFound(id);
    }

    final deletedJar = _withDeletedAt(jar, createClock().nowUtc);

    return Success(deletedJar);
  }

  @override
  Future<Result<void, JarFailure>> restore(Jar jar) async {
    if (!jar.isDeleted) {
      return JarNotDeletedFailure(
        message: 'Jar is not deleted: ${jar.id.value}',
      );
    }

    if (_jars.containsKey(jar.id)) {
      return JarAlreadyExistsFailure(
        message: 'Jar ID already exists: ${jar.id.value}',
      );
    }

    _jars[jar.id] = _withDeletedAt(jar, null);

    return const Success(null);
  }

  static Map<JarId, Jar> _validatedSeed(Iterable<Jar> jars) {
    final result = <JarId, Jar>{};

    for (final jar in jars) {
      if (jar.isDeleted) {
        throw ArgumentError('Deleted jar cannot be seeded: ${jar.id.value}');
      }

      if (result.containsKey(jar.id)) {
        throw ArgumentError('Jar ID is duplicated: ${jar.id.value}');
      }

      result[jar.id] = jar;
    }

    return result;
  }

  static JarNotFoundFailure _notFound(JarId id) {
    return JarNotFoundFailure(message: 'Jar ID was not found: ${id.value}');
  }

  List<Jar> _matchingJars(bool Function(Jar jar) matches) {
    return List.unmodifiable(_jars.values.where(matches));
  }

  static Jar _withArchivedAt(
    Jar jar, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return Jar(
      id: jar.id,
      name: jar.name,
      description: jar.description,
      kind: jar.kind,
      targets: jar.targets,
      icon: jar.icon,
      color: jar.color,
      sortOrder: jar.sortOrder,
      archivedAt: archivedAt,
      deletedAt: jar.deletedAt,
      createdAt: jar.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: jar.entityVersion,
    );
  }

  static Jar _withDeletedAt(Jar jar, DateTime? deletedAt) {
    return Jar(
      id: jar.id,
      name: jar.name,
      description: jar.description,
      kind: jar.kind,
      targets: jar.targets,
      icon: jar.icon,
      color: jar.color,
      sortOrder: jar.sortOrder,
      archivedAt: jar.archivedAt,
      deletedAt: deletedAt,
      createdAt: jar.createdAt,
      modifiedAt: jar.modifiedAt,
      entityVersion: jar.entityVersion,
    );
  }
}
