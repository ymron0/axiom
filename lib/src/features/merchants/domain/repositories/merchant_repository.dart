// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_active_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_deleted_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_archived_failure.dart';

/// Domain-facing contract for storing and retrieving [Merchant] entities.
///
/// ## Semantics
///
/// Merchants with a non-null [Merchant.deletedAt] are absent from persistence.
/// Archived merchants remain persisted and are returned by general queries.
/// Deletion is physical: this interface returns, but does not retain, the
/// deleted snapshot. A caller that needs restoration must retain that snapshot
/// and pass it to [restore].
abstract interface class MerchantRepository {
  /// Stores a new active [merchant].
  ///
  /// Fails with [MerchantAlreadyExistsFailure] when a merchant with the same
  /// identity already exists.
  ///
  /// Fails with [MerchantAlreadyDeletedFailure] when [Merchant.deletedAt] is
  /// not `null`.
  Future<Result<void, MerchantFailure>> create(Merchant merchant);

  /// Returns all persisted merchants.
  ///
  /// Returns an empty list when no merchants exist.
  Future<Result<List<Merchant>, MerchantFailure>> getAll();

  /// Returns persisted merchants that are not archived.
  Future<Result<List<Merchant>, MerchantFailure>> getActive();

  /// Returns persisted merchants that are archived.
  Future<Result<List<Merchant>, MerchantFailure>> getArchived();

  /// Returns the persisted merchant identified by [id].
  ///
  /// Returns `null` when no merchant with [id] exists.
  Future<Result<Merchant?, MerchantFailure>> getById(MerchantId id);

  /// Returns persisted merchants whose name contains [query].
  ///
  /// Matching is based on a substring of the merchant name.
  /// For example, `"mazo"` matches `"Amazon"`.
  ///
  /// Matching should be case-insensitive.
  ///
  /// Returns an empty list when no merchants match.
  Future<Result<List<Merchant>, MerchantFailure>> search(String query);

  /// Replaces the persisted snapshot of [merchant].
  ///
  /// Fails with [MerchantNotFoundFailure] when the merchant does not exist.
  ///
  /// Fails with [MerchantAlreadyDeletedFailure] when the merchant is deleted.
  Future<Result<void, MerchantFailure>> update(Merchant merchant);

  /// Archives the merchant identified by [id].
  ///
  /// [archivedAt] becomes its new modification timestamp.
  ///
  /// Fails with [MerchantAlreadyArchivedFailure] when it is already archived.
  Future<Result<Merchant, MerchantFailure>> archive(
    MerchantId id,
    DateTime archivedAt,
  );

  /// Removes archival state from the merchant identified by [id].
  ///
  /// Fails with [MerchantNotArchivedFailure] when it is not archived.
  Future<Result<Merchant, MerchantFailure>> unarchive(
    MerchantId id,
    DateTime modifiedAt,
  );

  /// Physically removes the merchant identified by [id].
  ///
  /// Fails with [MerchantNotFoundFailure] when the merchant does not exist.
  ///
  /// Returns the removed snapshot with [Merchant.deletedAt] set to the
  /// deletion time. The repository does not retain that snapshot.
  Future<Result<Merchant, MerchantFailure>> delete(MerchantId id);

  /// Restores the caller-retained deleted [merchant].
  ///
  /// On success, stores a non-deleted copy with [Merchant.deletedAt] set to
  /// `null`, preserving [Merchant.archivedAt].
  /// Fails with [MerchantAlreadyActiveFailure] when [merchant] is active or
  /// [MerchantAlreadyExistsFailure] when its identity already exists in
  /// persistence.
  Future<Result<void, MerchantFailure>> restore(Merchant merchant);
}
