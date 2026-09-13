// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_active_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_deleted_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';

/// Domain-facing contract for storing and retrieving [Custodian] entities.
///
/// ## Semantics
///
/// Custodians with a non-null [Custodian.deletedAt] are absent from
/// persistence. Deletion is physical: this interface returns, but does not
/// retain, the deleted snapshot. A caller that needs restoration must retain
/// that snapshot and pass it to [restore].
abstract interface class CustodianRepository {
  /// Stores a new active [custodian].
  ///
  /// Fails with [CustodianAlreadyExistsFailure] when a custodian with the same
  /// identity already exists.
  ///
  /// Fails when [Custodian.deletedAt] is not `null`.
  Future<Result<void, CustodianFailure>> create(Custodian custodian);

  /// Returns all persisted custodians.
  ///
  /// Returns an empty list when no custodians exist.
  Future<Result<List<Custodian>, CustodianFailure>> getAll();

  /// Returns the persisted custodian identified by [id].
  ///
  /// Returns `null` when no custodian with [id] exists.
  Future<Result<Custodian?, CustodianFailure>> getById(CustodianId id);

  /// Returns persisted custodians whose name contains [query].
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

  /// Physically removes the custodian identified by [id].
  ///
  /// Fails with [CustodianNotFoundFailure] when the custodian does not exist.
  ///
  /// Returns the removed snapshot with [Custodian.deletedAt] set to the
  /// deletion time. The repository does not retain that snapshot.
  Future<Result<Custodian, CustodianFailure>> delete(CustodianId id);

  /// Restores the caller-retained deleted [custodian].
  ///
  /// On success, stores an active copy with [Custodian.deletedAt] set to
  /// `null`. Fails with [CustodianAlreadyActiveFailure] when [custodian] is
  /// active or [CustodianAlreadyExistsFailure] when its identity already
  /// exists in persistence.
  Future<Result<void, CustodianFailure>> restore(Custodian custodian);
}
