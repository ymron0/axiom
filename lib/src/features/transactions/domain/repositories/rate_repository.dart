// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';

/// Repository contract for persisting and retrieving [Transaction] aggregates.
///
/// Implementations are responsible only for persistence concerns. Transaction
/// domain invariants must already be satisfied before an aggregate is passed to
/// this repository.
///
/// Repository operations return [TransactionFailure] when persistence or
/// retrieval cannot be completed.
///
/// Deletion is recoverable. A deleted transaction remains available for
/// restoration according to the implementation's deletion strategy.
abstract interface class TransactionRepository {
  /// Persists [transaction].
  ///
  /// Returns success when the transaction has been stored successfully.
  ///
  /// Returns a [TransactionFailure] when the transaction cannot be persisted.
  Future<Result<void, TransactionFailure>> create(Transaction transaction);

  /// Persists all supplied [transactions].
  ///
  /// Returns success when the transactions have been stored successfully.
  ///
  /// Returns a [TransactionFailure] when the operation cannot be completed.
  Future<Result<void, TransactionFailure>> createAll(
    Iterable<Transaction> transactions,
  );

  /// Retrieves all transactions available to normal repository queries.
  ///
  /// Returns an empty list when no transactions are found.
  ///
  /// Deleted transactions are excluded unless the repository contract or
  /// implementation explicitly defines otherwise.
  ///
  /// Returns a [TransactionFailure] when the transactions cannot be retrieved.
  Future<Result<List<Transaction>, TransactionFailure>> getAll();

  /// Retrieves the transaction identified by [id].
  ///
  /// Returns `null` when no matching transaction exists.
  ///
  /// Returns a [TransactionFailure] when the lookup cannot be completed.
  Future<Result<Transaction?, TransactionFailure>> getById(TransactionId id);

  /// Retrieves transactions matching [query].
  ///
  /// Matching semantics are defined by [TransactionQuery].
  ///
  /// Returns an empty list when no transactions match the query.
  ///
  /// Returns a [TransactionFailure] when the query cannot be completed.
  Future<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  );

  /// Persists the current state of [transaction].
  ///
  /// The transaction must already represent a valid domain state.
  ///
  /// Returns success when the stored transaction has been updated
  /// successfully.
  ///
  /// Returns a [TransactionFailure] when the transaction cannot be updated.
  Future<Result<void, TransactionFailure>> update(Transaction transaction);

  /// Marks the transaction identified by [id] as deleted.
  ///
  /// Deletion is recoverable; the transaction remains restorable through
  /// [restore].
  ///
  /// Returns the resulting deleted transaction on success.
  ///
  /// Returns a [TransactionFailure] when the transaction does not exist or
  /// cannot be deleted.
  Future<Result<Transaction, TransactionFailure>> delete(TransactionId id);

  /// Restores a previously deleted [transaction].
  ///
  /// Returns the resulting restored transaction on success.
  ///
  /// Returns a [TransactionFailure] when the transaction cannot be restored.
  Future<Result<Transaction, TransactionFailure>> restore(
    Transaction transaction,
  );
}
