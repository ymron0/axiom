// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_archived_failure.dart';

/// Domain-facing contract for storing and retrieving [Account] entities.
///
/// ## Semantics
///
/// Accounts with a non-null [Account.deletedAt] are absent from persistence.
/// Archived accounts remain persisted and are returned by [getAll].
/// Deletion is physical: this interface returns, but does not retain, the
/// deleted snapshot. A caller that needs restoration must retain that snapshot
/// and pass it to [restore].
abstract interface class AccountRepository {
  /// Stores a new active [account].
  ///
  /// Fails with [AccountAlreadyExistsFailure] when an account with the same
  /// identity already exists.
  ///
  /// Fails with [AccountAlreadyDeletedFailure] when [Account.deletedAt] is not
  /// `null`.
  ///
  /// Fails with [AccountAlreadyArchivedFailure] when [Account.archivedAt] is
  /// not `null`.
  Future<Result<void, AccountFailure>> create(Account account);

  /// Returns all persisted accounts.
  ///
  /// Returns an empty list when no accounts exist.
  Future<Result<List<Account>, AccountFailure>> getAll();

  /// Returns persisted accounts that are not archived.
  Future<Result<List<Account>, AccountFailure>> getActive();

  /// Returns persisted accounts that are archived.
  Future<Result<List<Account>, AccountFailure>> getArchived();

  /// Returns the persisted account identified by [id].
  ///
  /// Returns `null` when no account with [id] exists.
  Future<Result<Account?, AccountFailure>> getById(AccountId id);

  /// Returns all persisted accounts belonging to the custodian identified by
  /// [custodianId].
  ///
  /// Returns an empty list when the custodian has no accounts.
  Future<Result<List<Account>, AccountFailure>> getByCustodianId(
    CustodianId custodianId,
  );

  /// Returns persisted accounts whose name contains [query].
  ///
  /// Matching is case-insensitive and based on a substring of the account
  /// name.
  ///
  /// For example, `"avin"` matches `"Savings"`.
  ///
  /// Returns an empty list when no accounts match.
  Future<Result<List<Account>, AccountFailure>> search(String query);

  /// Replaces the persisted snapshot of [account].
  ///
  /// Fails with [AccountNotFoundFailure] when the account does not exist.
  ///
  /// Fails with [AccountAlreadyDeletedFailure] when the account is currently
  /// deleted.
  Future<Result<void, AccountFailure>> update(Account account);

  /// Archives [id].
  ///
  /// [archivedAt] becomes its new modification timestamp.
  ///
  /// Fails with [AccountNotFoundFailure] when the account does not exist.
  ///
  /// Fails with [AccountAlreadyArchivedFailure] when the requested account is
  /// already archived.
  Future<Result<Account, AccountFailure>> archive(
    AccountId id,
    DateTime archivedAt,
  );

  /// Unarchives [id].
  ///
  /// [modifiedAt] becomes its new modification timestamp.
  ///
  /// Fails with [AccountNotFoundFailure] when the account does not exist.
  ///
  /// Fails with [AccountNotArchivedFailure] when the requested account is not
  /// archived.
  Future<Result<Account, AccountFailure>> unarchive(
    AccountId id,
    DateTime modifiedAt,
  );

  /// Physically removes the account identified by [id].
  ///
  /// Fails with [AccountNotFoundFailure] when the account does not exist.
  ///
  /// Returns the removed snapshot with [Account.deletedAt] set to the deletion
  /// time. The repository does not retain that snapshot.
  Future<Result<Account, AccountFailure>> delete(AccountId id);

  /// Restores the caller-retained deleted [account].
  ///
  /// On success, stores a non-deleted copy with [Account.deletedAt] set to
  /// `null`, preserving [Account.archivedAt].
  /// Fails with [AccountAlreadyActiveFailure] when [account] is active or
  /// [AccountAlreadyExistsFailure] when its identity already exists in
  /// persistence.
  Future<Result<void, AccountFailure>> restore(Account account);
}
