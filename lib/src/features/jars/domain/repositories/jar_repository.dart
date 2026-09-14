// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';

/// Domain-facing contract for storing and retrieving [Jar] entities.
///
/// ## Persistence semantics
///
/// Deleted jars are absent from persistence.
///
/// Archived jars remain persisted and are returned by general queries unless a
/// query explicitly requests only archived or only unarchived jars.
///
/// ## Archival
///
/// Archiving is reversible and does not affect historical transaction
/// references.
///
/// [archive] and [unarchive] persist explicit lifecycle transitions while
/// retaining the jar identity and all target history.
///
/// ## Deletion
///
/// Deletion is physical. The repository returns the removed snapshot with
/// [Jar.deletedAt] populated, but does not retain it.
///
/// A caller that supports undo or restoration must retain the returned snapshot
/// and later pass it to [restore].
///
/// The repository does not determine whether transactions reference the jar.
/// That cross-feature check must occur before [delete].
abstract interface class JarRepository {
  /// Stores a new, unarchived, non-deleted [jar].
  Future<Result<void, JarFailure>> create(Jar jar);

  /// Returns every persisted jar, including archived jars.
  Future<Result<List<Jar>, JarFailure>> getAll();

  /// Returns every persisted unarchived jar.
  Future<Result<List<Jar>, JarFailure>> getActive();

  /// Returns every persisted archived jar.
  Future<Result<List<Jar>, JarFailure>> getArchived();

  /// Returns the persisted jar identified by [id].
  ///
  /// Returns `null` when no matching jar exists.
  Future<Result<Jar?, JarFailure>> getById(JarId id);

  /// Returns all persisted jars whose [Jar.kind] equals [kind].
  ///
  /// Archived jars are included.
  Future<Result<List<Jar>, JarFailure>> getByKind(JarKind kind);

  /// Returns persisted jars whose name contains [query].
  ///
  /// Matching is case-insensitive and substring-based. Archived jars are
  /// included.
  Future<Result<List<Jar>, JarFailure>> search(String query);

  /// Replaces the complete persisted snapshot of [jar].
  ///
  /// Archived jars may be updated. Deleted jars cannot be updated.
  Future<Result<void, JarFailure>> update(Jar jar);

  /// Archives the jar identified by [id].
  ///
  /// [archivedAt] becomes both the archive timestamp and the new modification
  /// timestamp.
  ///
  /// Returns the updated archived snapshot.
  Future<Result<Jar, JarFailure>> archive(JarId id, DateTime archivedAt);

  /// Removes the archival state from the jar identified by [id].
  ///
  /// [modifiedAt] becomes the jar's new modification timestamp.
  ///
  /// Returns the updated unarchived snapshot.
  Future<Result<Jar, JarFailure>> unarchive(JarId id, DateTime modifiedAt);

  /// Physically removes the jar identified by [id].
  ///
  /// Returns the removed snapshot with [Jar.deletedAt] populated.
  ///
  /// Transaction usage checks must occur before calling this method.
  Future<Result<Jar, JarFailure>> delete(JarId id);

  /// Restores a caller-retained deleted [jar].
  ///
  /// Restoration clears [Jar.deletedAt] but preserves [Jar.archivedAt].
  /// Therefore a jar that was archived when deleted is restored as archived.
  Future<Result<void, JarFailure>> restore(Jar jar);
}
