// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_in_use_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';

/// Domain-facing contract for storing and retrieving [Account] entities.
///
/// ## Semantics
///
/// Accounts are soft-deleted. A deleted account remains in persistence with a
/// non-null [Account.deletedAt] and can later be restored.
///
/// Retrieval operations return active accounts only unless otherwise
/// specified.
///
/// An account cannot be deleted while one or more transactions reference it.
/// Those transactions must first be deleted explicitly by the caller.
abstract interface class AccountRepository {
  /// Stores a new active [account].
  ///
  /// Fails with [AccountAlreadyExistsFailure] when an account with the same
  /// identity already exists.
  ///
  /// Fails when [Account.deletedAt] is not `null`.
  Future<Result<void, AccountFailure>> create(Account account);

  /// Returns all active accounts.
  ///
  /// Returns an empty list when no active accounts exist.
  Future<Result<List<Account>, AccountFailure>> getAll();

  /// Returns the active account identified by [id].
  ///
  /// Returns `null` when no active account with [id] exists.
  Future<Result<Account?, AccountFailure>> getById(AccountId id);

  /// Returns all active accounts belonging to the custodian identified by
  /// [custodianId].
  ///
  /// Returns an empty list when the custodian has no active accounts.
  Future<Result<List<Account>, AccountFailure>> getByCustodianId(
    CustodianId custodianId,
  );

  /// Returns active accounts whose name contains [query].
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

  /// Soft-deletes the account identified by [id].
  ///
  /// Fails with [AccountNotFoundFailure] when the account does not exist.
  ///
  /// Fails with [AccountAlreadyDeletedFailure] when the account is already
  /// deleted.
  ///
  /// Fails with [AccountInUseFailure] while one or more transactions reference
  /// the account. Those transactions must be deleted before the account can be
  /// deleted.
  Future<Result<void, AccountFailure>> delete(AccountId id);

  /// Restores the deleted account identified by [id].
  ///
  /// Fails with [AccountNotFoundFailure] when the account does not exist.
  ///
  /// Fails with [AccountAlreadyActiveFailure] when the account is already
  /// active.
  Future<Result<void, AccountFailure>> restore(AccountId id);
}
