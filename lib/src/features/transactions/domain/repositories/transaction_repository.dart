// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';

/// Domain-facing interface for storing and retrieving [Transaction] aggregates.
///
/// ## Semantics
///
/// Transactions with a non-null [Transaction.deletedAt] are absent from
/// persistence.
///
/// Deletion is physical. A caller that needs restoration must retain the
/// deleted snapshot and pass it to [restore].
///
/// Offset transactions are ordinary transactions whose [Transaction.offset]
/// references another transaction.
///
/// They must be created through [createOffset], rather than [create] or
/// [createAll], because offset validation and persistence must occur atomically.
///
/// ## Guarantees
///
/// Batch creation is atomic.
///
/// Updates preserve [Transaction.entityVersion], which identifies the
/// aggregate's class version rather than an update count.
///
/// Delete and restore use a caller-owned deleted snapshot.
///
/// Expected domain and persistence failures are returned as
/// [TransactionFailure] values inside [Result].
abstract interface class TransactionRepository {
  /// Stores the active standalone [transaction].
  ///
  /// Offset transactions are rejected and must use [createOffset].
  ///
  /// Returns a failure when the transaction is deleted or its identifier is
  /// already persisted.
  Future<Result<void, TransactionFailure>> create(Transaction transaction);

  /// Atomically stores every standalone transaction in [transactions].
  ///
  /// Offset transactions are rejected and must use [createOffset].
  ///
  /// If any transaction cannot be stored, none are stored.
  /// An empty list succeeds without changing persistence.
  Future<Result<void, TransactionFailure>> createAll(
    List<Transaction> transactions,
  );

  /// Atomically validates and stores one transaction offset.
  ///
  /// Validation includes:
  ///
  /// - resolving the referenced original transaction;
  /// - validating relationship and direction semantics;
  /// - checking all existing offsets;
  /// - preventing cumulative offsets above the original amount; and
  /// - validating allocation capacity.
  ///
  /// The validation and write must occur within one persistence transaction.
  ///
  /// The supplied transaction must be active and contain an offset
  /// relationship.
  Future<Result<void, TransactionFailure>> createOffset(
    Transaction transaction,
  );

  /// Returns all persisted transactions.
  ///
  /// Results are ordered by persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>> getAll();

  /// Returns the persisted transaction identified by [id].
  ///
  /// Returns `null` when no matching transaction exists.
  /// Deleted transactions are not persisted and therefore are not returned.
  Future<Result<Transaction?, TransactionFailure>> getById(TransactionId id);

  /// Returns active offset transactions referencing [transactionId].
  ///
  /// Results preserve persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>>
  getOffsetsForTransaction(TransactionId transactionId);

  /// Returns ledger entries affecting [accountId].
  ///
  /// Results preserve the containing transactions' persistence insertion order
  /// and each transaction's ledger-entry order.
  Future<Result<List<LedgerEntry>, TransactionFailure>>
  getLedgerEntriesByAccountId(AccountId accountId);

  /// Returns transactions affecting [accountId].
  ///
  /// Results preserve persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByAccountId(AccountId accountId);

  /// Returns transactions associated with [merchantId].
  ///
  /// Results preserve persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByMerchantId(MerchantId merchantId);

  /// Returns transactions allocated to [categoryId].
  ///
  /// Results preserve persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByCategoryId(CategoryId categoryId);

  /// Returns transactions allocated to [jarId].
  ///
  /// Results preserve persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>> getTransactionsByJarId(
    JarId jarId,
  );

  /// Whether at least one persisted transaction affects [accountId].
  Future<Result<bool, TransactionFailure>> existsByAccountId(
    AccountId accountId,
  );

  /// Whether at least one persisted transaction is associated with [merchantId].
  Future<Result<bool, TransactionFailure>> existsByMerchantId(
    MerchantId merchantId,
  );

  /// Whether at least one persisted transaction is allocated to [categoryId].
  Future<Result<bool, TransactionFailure>> existsByCategoryId(
    CategoryId categoryId,
  );

  /// Whether at least one persisted transaction is allocated to [jarId].
  Future<Result<bool, TransactionFailure>> existsByJarId(JarId jarId);

  /// Returns persisted transactions matching [query].
  ///
  /// An empty query returns all persisted transactions. Results preserve
  /// persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  );

  /// Replaces the stored snapshot of [transaction].
  ///
  /// Offset relationship identity cannot be changed by an update.
  ///
  /// Updates that would invalidate existing offsets are rejected.
  ///
  /// The supplied transaction must be active and have the currently persisted
  /// [Transaction.entityVersion]. The offset relationship cannot be added,
  /// removed, or changed through this method.
  Future<Result<void, TransactionFailure>> update(Transaction transaction);

  /// Physically removes the transaction identified by [id].
  ///
  /// An original transaction cannot be deleted while active offset
  /// transactions reference it.
  ///
  /// An offset transaction itself may be deleted.
  ///
  /// Deletion removes the persisted record; it does not retain a deleted
  /// snapshot for later restoration.
  Future<Result<void, TransactionFailure>> delete(TransactionId id);

  /// Restores the caller-retained deleted [transaction].
  ///
  /// Offset invariants are revalidated before persistence.
  /// The deleted snapshot is not mutated, and the restored record has a null
  /// [Transaction.deletedAt].
  Future<Result<void, TransactionFailure>> restore(Transaction transaction);
}
