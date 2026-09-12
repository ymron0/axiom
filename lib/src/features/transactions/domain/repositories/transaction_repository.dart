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
/// Deleted transactions are retained and can be restored. Normal retrieval
/// excludes deleted transactions.
///
/// ## Contract
///
/// Batch creation is atomic. Updates use [Transaction.entityVersion] for
/// optimistic concurrency.
abstract interface class TransactionRepository {
  /// Stores [transaction].
  ///
  /// Fails when its identity already exists.
  Future<Result<void, TransactionFailure>> create(Transaction transaction);

  /// Atomically stores every transaction in [transactions].
  ///
  /// If any transaction cannot be stored, none are stored.
  Future<Result<void, TransactionFailure>> createAll(
    List<Transaction> transactions,
  );

  /// Returns all non-deleted transactions.
  ///
  /// Returns an empty list when none exist.
  Future<Result<List<Transaction>, TransactionFailure>> getAll();

  /// Returns the non-deleted transaction identified by [id].
  ///
  /// Returns `null` when no matching transaction exists.
  Future<Result<Transaction?, TransactionFailure>> getById(TransactionId id);

  /// Returns non-deleted transactions matching [query].
  ///
  /// Matching semantics are defined by [TransactionQuery].
  Future<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  );

  /// Replaces the stored snapshot of [transaction].
  ///
  /// Fails when the transaction does not exist or its entity version conflicts
  /// with the persisted version.
  Future<Result<void, TransactionFailure>> update(Transaction transaction);

  /// Marks the transaction identified by [id] as deleted.
  ///
  /// Fails when the transaction does not exist or is already deleted.
  Future<Result<void, TransactionFailure>> delete(TransactionId id);

  /// Restores the deleted transaction identified by [id].
  ///
  /// Fails when the transaction does not exist or is not deleted.
  Future<Result<void, TransactionFailure>> restore(TransactionId id);
}
