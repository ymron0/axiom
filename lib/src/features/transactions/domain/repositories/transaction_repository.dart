// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';

/// Domain-facing contract for storing and retrieving [Transaction] aggregates.
///
/// ## Semantics
///
/// Transactions with a non-null [Transaction.deletedAt] are absent from
/// persistence. Deletion is physical: this interface does not retain the
/// deleted snapshot. A caller that needs restoration must retain the deleted
/// snapshot and pass it to [restore].
///
/// ## Contract
///
/// Batch creation is atomic. Updates preserve [Transaction.entityVersion],
/// which identifies the aggregate's class version rather than an update count.
/// Delete and restore use a caller-owned deleted snapshot.
abstract interface class TransactionRepository {
  /// Stores the active [transaction].
  ///
  /// Fails when its identity already exists or [Transaction.deletedAt] is not
  /// `null`.
  Future<Result<void, TransactionFailure>> create(Transaction transaction);

  /// Atomically stores every transaction in [transactions].
  ///
  /// If any transaction is deleted or otherwise cannot be stored, none are
  /// stored.
  Future<Result<void, TransactionFailure>> createAll(
    List<Transaction> transactions,
  );

  /// Returns all persisted transactions.
  ///
  /// Returns an empty list when none exist.
  Future<Result<List<Transaction>, TransactionFailure>> getAll();

  /// Returns the persisted transaction identified by [id].
  ///
  /// Returns `null` when no matching transaction exists.
  Future<Result<Transaction?, TransactionFailure>> getById(TransactionId id);

  /// Returns persisted transactions matching [query].
  ///
  /// Matching semantics are defined by [TransactionQuery].
  Future<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  );

  /// Replaces the stored snapshot of [transaction].
  ///
  /// Fails when the transaction is deleted, does not exist, or its class
  /// version differs from the persisted version. An update never increments
  /// [Transaction.entityVersion].
  Future<Result<void, TransactionFailure>> update(Transaction transaction);

  /// Physically removes the transaction identified by [id].
  ///
  /// The removed snapshot is not retained by the repository and is not marked
  /// deleted by this operation.
  ///
  /// Fails when the transaction does not exist.
  Future<Result<void, TransactionFailure>> delete(TransactionId id);

  /// Restores the caller-retained deleted [transaction] after it was physically
  /// deleted.
  ///
  /// On success, stores an active copy with [Transaction.deletedAt] set to
  /// `null`. Fails when [Transaction.deletedAt] is `null` or its identity
  /// already exists in persistence.
  Future<Result<void, TransactionFailure>> restore(Transaction transaction);
}
