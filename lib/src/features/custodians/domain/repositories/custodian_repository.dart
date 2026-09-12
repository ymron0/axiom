// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';

/// Domain-facing contract for storing and retrieving [Custodian] entities.
///
/// ## Semantics
///
/// Custodians are soft-deleted. A deleted custodian remains in persistence
/// with a non-null [Custodian.deletedAt] and can later be restored.
///
/// Retrieval operations return active custodians only unless otherwise
/// specified.
///
/// A custodian cannot be deleted while one or more accounts reference it.
/// Those accounts must first be deleted explicitly by the caller.
abstract interface class CustodianRepository {
  /// Stores a new active [custodian].
  ///
  /// Fails with [CustodianAlreadyExistsFailure] when a custodian with the same
  /// identity already exists.
  ///
  /// Fails when [Custodian.deletedAt] is not `null`.
  Future<Result<void, CustodianFailure>> create(Custodian custodian);

  /// Returns all active custodians.
  ///
  /// Returns an empty list when no active custodians exist.
  Future<Result<List<Custodian>, CustodianFailure>> getAll();

  /// Returns the active custodian identified by [id].
  ///
  /// Returns `null` when no active custodian with [id] exists.
  Future<Result<Custodian?, CustodianFailure>> getById(CustodianId id);

  /// Returns active custodians whose name contains [query].
  ///
  /// Matching is case-insensitive and based on a substring of the custodian
  /// name.
  ///
  /// For example, `"evol"` matches `"Revolut"`.
  ///
  /// Returns an empty list when no custodians match.
  Future<Result<List<Custodian>, CustodianFailure>> search(String query);

  /// Replaces the persisted snapshot of [custodian].
  ///
  /// Fails with [CustodianNotFoundFailure] when the custodian does not exist.
  ///
  /// Fails with [CustodianAlreadyDeletedFailure] when the custodian is
  /// currently deleted.
  Future<Result<void, CustodianFailure>> update(Custodian custodian);

  /// Soft-deletes the custodian identified by [id].
  ///
  /// Fails with [CustodianNotFoundFailure] when the custodian does not exist.
  ///
  /// Fails with [CustodianAlreadyDeletedFailure] when the custodian is already
  /// deleted.
  ///
  /// Fails with [CustodianInUseFailure] while one or more accounts reference
  /// the custodian. Those accounts must be deleted before the custodian can be
  /// deleted.
  Future<Result<void, CustodianFailure>> delete(CustodianId id);

  /// Restores the deleted custodian identified by [id].
  ///
  /// Fails with [CustodianNotFoundFailure] when the custodian does not exist.
  ///
  /// Fails with [CustodianAlreadyActiveFailure] when the custodian is already
  /// active.
  Future<Result<void, CustodianFailure>> restore(CustodianId id);
}
