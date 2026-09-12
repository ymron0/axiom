// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';

/// Domain-facing contract for storing and retrieving [Merchant] entities.
///
/// ## Semantics
///
/// Merchants are soft-deleted. A deleted merchant remains in persistence with
/// a non-null [Merchant.deletedAt] and can later be restored.
///
/// Retrieval operations return active merchants only unless otherwise
/// specified.
///
/// A merchant cannot be deleted while one or more transactions reference it.
/// Those transactions must first be deleted explicitly by the caller.
abstract interface class MerchantRepository {
  /// Stores a new active [merchant].
  ///
  /// Fails when a merchant with the same identity already exists or when
  /// [Merchant.deletedAt] is not `null`.
  Future<Result<void, MerchantFailure>> create(Merchant merchant);

  /// Returns all active merchants.
  ///
  /// Returns an empty list when no active merchants exist.
  Future<Result<List<Merchant>, MerchantFailure>> getAll();

  /// Returns the active merchant identified by [id].
  ///
  /// Returns `null` when no active merchant with [id] exists.
  Future<Result<Merchant?, MerchantFailure>> getById(MerchantId id);

  /// Returns active merchants whose name contains [query].
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
  /// Fails when the merchant does not exist or is deleted.
  Future<Result<void, MerchantFailure>> update(Merchant merchant);

  /// Soft-deletes the merchant identified by [id].
  ///
  /// Fails when the merchant does not exist, is already deleted, or is still
  /// referenced by one or more transactions.
  ///
  /// Transactions referencing the merchant must be deleted explicitly before
  /// the merchant can be deleted.
  Future<Result<void, MerchantFailure>> delete(MerchantId id);

  /// Restores the deleted merchant identified by [id].
  ///
  /// Fails when the merchant does not exist or is already active.
  Future<Result<void, MerchantFailure>> restore(MerchantId id);
}
