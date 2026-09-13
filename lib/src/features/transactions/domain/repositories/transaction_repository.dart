// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/budget_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
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

  /// Returns transactions affecting [accountId] in persistence insertion order.
  ///
  /// Returns an empty list when none affect the account.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByAccountId(AccountId accountId);

  /// Returns transactions associated with [merchantId] in persistence insertion
  /// order.
  ///
  /// Returns an empty list when none are associated with the merchant.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByMerchantId(MerchantId merchantId);

  /// Returns transactions allocated to [categoryId] in persistence insertion
  /// order.
  ///
  /// Returns an empty list when none are allocated to the category.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByCategoryId(CategoryId categoryId);

  /// Returns transactions allocated to [budgetId] in persistence insertion
  /// order.
  ///
  /// Returns an empty list when none are allocated to the budget.
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByBudgetId(BudgetId budgetId);

  /// Returns transactions allocated to [jarId] in persistence insertion order.
  ///
  /// Returns an empty list when none are allocated to the jar.
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

  /// Whether at least one persisted transaction is allocated to [budgetId].
  Future<Result<bool, TransactionFailure>> existsByBudgetId(BudgetId budgetId);

  /// Whether at least one persisted transaction is allocated to [jarId].
  Future<Result<bool, TransactionFailure>> existsByJarId(JarId jarId);

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
