import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart'
    as persistence;
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset.dart';
import 'package:sembast/sembast.dart' hide Transaction;

/// Persists transaction aggregates in the configured Sembast database.
///
/// Offset creation is validated atomically against the original transaction and
/// every previously persisted offset.
///
/// Ordinary transaction creation deliberately rejects offset transactions so
/// callers cannot bypass the atomic over-offset protection.
///
/// Tag references are persisted as part of the transaction aggregate. This
/// repository does not resolve or validate tag entities themselves because
/// cross-feature referential integrity is coordinated by the application
/// layer.
///
/// Tag-related queries operate exclusively on [Transaction.tagIds].
final class SembastTransactionRepositoryImpl implements TransactionRepository {
  /// Creates a transaction repository using an already-open [database].
  const SembastTransactionRepositoryImpl({
    required Database database,
    TransactionOffsetPolicy offsetPolicy = const TransactionOffsetPolicy(),
  }) : _database = database, // ignore: prefer_initializing_formals
       _offsetPolicy = offsetPolicy; // ignore: prefer_initializing_formals

  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.transactions;

  final Database _database;
  final TransactionOffsetPolicy _offsetPolicy;

  @override
  Future<Result<void, TransactionFailure>> create(
    Transaction transaction,
  ) async {
    if (transaction.isDeleted) {
      return TransactionAlreadyDeletedFailure(
        message:
            'Deleted transaction cannot be created: '
            '${transaction.id.value}',
      );
    }

    if (transaction.isOffset) {
      return const TransactionOffsetValidationFailure(
        message: 'Offset transactions must be created through createOffset().',
      );
    }

    return guardPersistenceOperation(() async {
      return _database.transaction<Result<void, TransactionFailure>>((
        databaseTransaction,
      ) async {
        final record = _store.record(transaction.id.value);

        if (await record.exists(databaseTransaction)) {
          return TransactionAlreadyExistsFailure(
            message:
                'Transaction ID already exists: '
                '${transaction.id.value}',
          );
        }

        final persistenceOrder = await _nextPersistenceOrder(
          databaseTransaction,
        );

        final model = TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: persistenceOrder,
        );

        await record.put(databaseTransaction, model.toRecord());

        return const Success(null);
      });
    });
  }

  @override
  Future<Result<void, TransactionFailure>> createAll(
    List<Transaction> transactions,
  ) async {
    for (final transaction in transactions) {
      if (transaction.isDeleted) {
        return TransactionAlreadyDeletedFailure(
          message:
              'Deleted transaction cannot be created: '
              '${transaction.id.value}',
        );
      }

      if (transaction.isOffset) {
        return const TransactionOffsetValidationFailure(
          message: 'Offset transactions cannot be created through createAll().',
        );
      }
    }

    final requestedIds = <TransactionId>{};

    for (final transaction in transactions) {
      if (!requestedIds.add(transaction.id)) {
        return TransactionAlreadyExistsFailure(
          message:
              'Transaction ID is duplicated: '
              '${transaction.id.value}',
        );
      }
    }

    if (transactions.isEmpty) {
      return const Success(null);
    }

    return guardPersistenceOperation(() async {
      return _database.transaction<Result<void, TransactionFailure>>((
        databaseTransaction,
      ) async {
        for (final transaction in transactions) {
          final exists = await _store
              .record(transaction.id.value)
              .exists(databaseTransaction);

          if (exists) {
            return TransactionAlreadyExistsFailure(
              message:
                  'Transaction ID already exists: '
                  '${transaction.id.value}',
            );
          }
        }

        var persistenceOrder = await _nextPersistenceOrder(databaseTransaction);

        for (final transaction in transactions) {
          final model = TransactionPersistenceModel.fromEntity(
            transaction,
            persistenceOrder: persistenceOrder,
          );

          await _store
              .record(transaction.id.value)
              .put(databaseTransaction, model.toRecord());

          persistenceOrder++;
        }

        return const Success(null);
      });
    });
  }

  @override
  Future<Result<void, TransactionFailure>> createOffset(
    Transaction transaction,
  ) async {
    if (transaction.isDeleted) {
      return TransactionAlreadyDeletedFailure(
        message:
            'Deleted offset transaction cannot be created: '
            '${transaction.id.value}',
      );
    }

    if (!transaction.isOffset) {
      return const TransactionOffsetValidationFailure(
        message:
            'createOffset() requires a transaction containing an offset '
            'relationship.',
      );
    }

    return guardPersistenceOperation(() async {
      return _database.transaction<Result<void, TransactionFailure>>((
        databaseTransaction,
      ) async {
        final record = _store.record(transaction.id.value);

        if (await record.exists(databaseTransaction)) {
          return TransactionAlreadyExistsFailure(
            message:
                'Transaction ID already exists: '
                '${transaction.id.value}',
          );
        }

        final transactions = await _readAll(databaseTransaction);

        final validation = _validateRelationshipGraph(
          candidate: transaction,
          persistedTransactions: transactions,
        );

        if (validation case final Failure<TransactionFailure> failure) {
          return failure;
        }

        final persistenceOrder = await _nextPersistenceOrder(
          databaseTransaction,
        );

        final model = TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: persistenceOrder,
        );

        await record.put(databaseTransaction, model.toRecord());

        return const Success(null);
      });
    });
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>> getAll() {
    return guardPersistenceOperation(() async {
      final transactions = await _readAll(_database);

      return Success(transactions);
    });
  }

  @override
  Future<Result<Transaction?, TransactionFailure>> getById(TransactionId id) {
    return guardPersistenceOperation(() async {
      final record = await _store.record(id.value).get(_database);

      if (record == null) {
        return const Success<Transaction?>(null);
      }

      final transaction = TransactionPersistenceModel.fromRecord(
        id.value,
        record,
      ).toEntity();

      return Success<Transaction?>(transaction);
    });
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>>
  getOffsetsForTransaction(TransactionId transactionId) {
    return _findWhere(
      (transaction) =>
          transaction.offset?.originalTransactionId == transactionId,
    );
  }

  @override
  Future<Result<List<LedgerEntry>, TransactionFailure>>
  getLedgerEntriesByAccountId(AccountId accountId) {
    return guardPersistenceOperation(() async {
      final transactions = await _readAll(_database);

      final entries = transactions
          .expand((transaction) => transaction.ledgerEntries)
          .where((entry) => entry.accountId == accountId);

      return Success(List<LedgerEntry>.unmodifiable(entries));
    });
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByAccountId(AccountId accountId) {
    return _findWhere(
      (transaction) => transaction.ledgerEntries.any(
        (entry) => entry.accountId == accountId,
      ),
    );
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByMerchantId(MerchantId merchantId) {
    return _findWhere((transaction) => transaction.merchantId == merchantId);
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>>
  getTransactionsByCategoryId(CategoryId categoryId) {
    return _findWhere(
      (transaction) =>
          transaction.splits.any((split) => split.categoryId == categoryId),
    );
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>> getTransactionsByJarId(
    JarId jarId,
  ) {
    return _findWhere(
      (transaction) => transaction.splits.any((split) => split.jarId == jarId),
    );
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>> getTransactionsByTagId(
    TagId tagId,
  ) {
    return _findWhere((transaction) => transaction.tagIds.contains(tagId));
  }

  @override
  Future<Result<bool, TransactionFailure>> existsByAccountId(
    AccountId accountId,
  ) {
    return _existsWhere(
      (transaction) => transaction.ledgerEntries.any(
        (entry) => entry.accountId == accountId,
      ),
    );
  }

  @override
  Future<Result<bool, TransactionFailure>> existsByMerchantId(
    MerchantId merchantId,
  ) {
    return _existsWhere((transaction) => transaction.merchantId == merchantId);
  }

  @override
  Future<Result<bool, TransactionFailure>> existsByCategoryId(
    CategoryId categoryId,
  ) {
    return _existsWhere(
      (transaction) =>
          transaction.splits.any((split) => split.categoryId == categoryId),
    );
  }

  @override
  Future<Result<bool, TransactionFailure>> existsByJarId(JarId jarId) {
    return _existsWhere(
      (transaction) => transaction.splits.any((split) => split.jarId == jarId),
    );
  }

  @override
  Future<Result<bool, TransactionFailure>> existsByTagId(TagId tagId) {
    return _existsWhere((transaction) => transaction.tagIds.contains(tagId));
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  ) {
    return guardPersistenceOperation(() async {
      final transactions = await _readAll(_database);

      if (query.isEmpty) {
        return Success(transactions);
      }

      final matches = transactions.where(
        (transaction) => _matchesQuery(transaction, query),
      );

      return Success(List<Transaction>.unmodifiable(matches));
    });
  }

  @override
  Future<Result<void, TransactionFailure>> update(
    Transaction transaction,
  ) async {
    if (transaction.isDeleted) {
      return TransactionAlreadyDeletedFailure(
        message:
            'Deleted transaction cannot be updated: '
            '${transaction.id.value}',
      );
    }

    return guardPersistenceOperation(() async {
      return _database.transaction<Result<void, TransactionFailure>>((
        databaseTransaction,
      ) async {
        final recordRef = _store.record(transaction.id.value);
        final storedRecord = await recordRef.get(databaseTransaction);

        if (storedRecord == null) {
          return _notFound(transaction.id);
        }

        final storedModel = TransactionPersistenceModel.fromRecord(
          transaction.id.value,
          storedRecord,
        );

        final storedTransaction = storedModel.toEntity();

        if (transaction.entityVersion != storedTransaction.entityVersion) {
          return TransactionVersionConflictFailure(
            message:
                'Transaction version conflicts with the stored version: '
                '${transaction.id.value}',
          );
        }

        if (!_sameOffset(storedTransaction.offset, transaction.offset)) {
          return const TransactionOffsetValidationFailure(
            message:
                'A transaction offset relationship cannot be added, removed, '
                'or changed through update().',
          );
        }

        final transactions = await _readAll(databaseTransaction);

        final validation = _validateRelationshipGraph(
          candidate: transaction,
          persistedTransactions: transactions,
        );

        if (validation case final Failure<TransactionFailure> failure) {
          return failure;
        }

        final replacement = TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: storedModel.persistenceOrder,
        );

        await recordRef.put(databaseTransaction, replacement.toRecord());

        return const Success(null);
      });
    });
  }

  @override
  Future<Result<void, TransactionFailure>> delete(TransactionId id) {
    return guardPersistenceOperation(() async {
      return _database.transaction<Result<void, TransactionFailure>>((
        databaseTransaction,
      ) async {
        final record = _store.record(id.value);

        if (!await record.exists(databaseTransaction)) {
          return _notFound(id);
        }

        final transactions = await _readAll(databaseTransaction);

        final hasOffsets = transactions.any(
          (transaction) => transaction.offset?.originalTransactionId == id,
        );

        if (hasOffsets) {
          return TransactionOffsetValidationFailure(
            message:
                'Transaction ${id.value} cannot be deleted while active '
                'offset transactions reference it.',
          );
        }

        await record.delete(databaseTransaction);

        return const Success(null);
      });
    });
  }

  @override
  Future<Result<void, TransactionFailure>> restore(
    Transaction transaction,
  ) async {
    if (!transaction.isDeleted) {
      return TransactionNotDeletedFailure(
        message:
            'Transaction is not deleted: '
            '${transaction.id.value}',
      );
    }

    final restored = transaction.copyWith(deletedAt: null);

    return guardPersistenceOperation(() async {
      return _database.transaction<Result<void, TransactionFailure>>((
        databaseTransaction,
      ) async {
        final record = _store.record(transaction.id.value);

        if (await record.exists(databaseTransaction)) {
          return TransactionAlreadyExistsFailure(
            message:
                'Transaction ID already exists: '
                '${transaction.id.value}',
          );
        }

        final transactions = await _readAll(databaseTransaction);

        final validation = _validateRelationshipGraph(
          candidate: restored,
          persistedTransactions: transactions,
        );

        if (validation case final Failure<TransactionFailure> failure) {
          return failure;
        }

        final persistenceOrder = await _nextPersistenceOrder(
          databaseTransaction,
        );

        final model = TransactionPersistenceModel.fromEntity(
          restored,
          persistenceOrder: persistenceOrder,
        );

        await record.put(databaseTransaction, model.toRecord());

        return const Success(null);
      });
    });
  }

  Result<void, TransactionFailure> _validateRelationshipGraph({
    required Transaction candidate,
    required List<Transaction> persistedTransactions,
  }) {
    if (candidate.isOffset) {
      final relationship = candidate.offset!;

      final original = _findTransaction(
        persistedTransactions,
        relationship.originalTransactionId,
      );

      if (original == null) {
        return _notFound(relationship.originalTransactionId);
      }

      final existingOffsets = persistedTransactions.where(
        (transaction) =>
            transaction.id != candidate.id &&
            transaction.offset?.originalTransactionId == original.id,
      );

      return _offsetPolicy.validateNewOffset(
        original: original,
        offset: candidate,
        existingOffsets: existingOffsets,
      );
    }

    final offsets = persistedTransactions
        .where(
          (transaction) =>
              transaction.id != candidate.id &&
              transaction.offset?.originalTransactionId == candidate.id,
        )
        .toList(growable: false);

    if (offsets.isEmpty) {
      return const Success(null);
    }

    final acceptedOffsets = <Transaction>[];

    for (final offset in offsets) {
      final validation = _offsetPolicy.validateNewOffset(
        original: candidate,
        offset: offset,
        existingOffsets: acceptedOffsets,
      );

      if (validation case final Failure<TransactionFailure> failure) {
        return failure;
      }

      acceptedOffsets.add(offset);
    }

    return const Success(null);
  }

  /// Reads every transaction in persistence insertion order.
  Future<List<Transaction>> _readAll(DatabaseClient databaseClient) async {
    final snapshots = await _store.find(
      databaseClient,
      finder: Finder(
        sortOrders: <SortOrder>[
          SortOrder(TransactionPersistenceModel.persistenceOrderField),
        ],
      ),
    );

    return List<Transaction>.unmodifiable(
      snapshots.map(
        (snapshot) => TransactionPersistenceModel.fromRecord(
          snapshot.key,
          snapshot.value,
        ).toEntity(),
      ),
    );
  }

  /// Returns the next monotonic persistence insertion order.
  Future<int> _nextPersistenceOrder(DatabaseClient databaseClient) async {
    final snapshots = await _store.find(databaseClient);

    var maximum = 0;

    for (final snapshot in snapshots) {
      final order = TransactionPersistenceModel.readPersistenceOrder(
        snapshot.value,
      );

      if (order > maximum) {
        maximum = order;
      }
    }

    return maximum + 1;
  }

  /// Returns transactions satisfying [matches] in persistence insertion order.
  Future<Result<List<Transaction>, TransactionFailure>> _findWhere(
    bool Function(Transaction transaction) matches,
  ) {
    return guardPersistenceOperation(() async {
      final transactions = await _readAll(_database);

      return Success(
        List<Transaction>.unmodifiable(transactions.where(matches)),
      );
    });
  }

  /// Returns whether at least one persisted transaction satisfies [matches].
  Future<Result<bool, TransactionFailure>> _existsWhere(
    bool Function(Transaction transaction) matches,
  ) {
    return guardPersistenceOperation(() async {
      final transactions = await _readAll(_database);

      return Success(transactions.any(matches));
    });
  }

  /// Finds one transaction by identity from [transactions].
  static Transaction? _findTransaction(
    Iterable<Transaction> transactions,
    TransactionId id,
  ) {
    for (final transaction in transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }

    return null;
  }

  /// Whether two optional offset relationships represent the same relationship.
  static bool _sameOffset(TransactionOffset? first, TransactionOffset? second) {
    if (first == null && second == null) {
      return true;
    }

    if (first == null || second == null) {
      return false;
    }

    return first.originalTransactionId == second.originalTransactionId &&
        first.kind == second.kind;
  }

  /// Whether [transaction] satisfies every non-empty criterion in [query].
  ///
  /// Criteria belonging to different fields use AND semantics.
  ///
  /// Multiple values within one field use OR semantics. For tags this means
  /// that a transaction matches when it references at least one tag contained
  /// in [TransactionQuery.tagIds].
  static bool _matchesQuery(Transaction transaction, TransactionQuery query) {
    return (query.kinds.isEmpty || query.kinds.contains(transaction.kind)) &&
        (query.states.isEmpty || query.states.contains(transaction.state)) &&
        (query.merchantIds.isEmpty ||
            query.merchantIds.contains(transaction.merchantId)) &&
        (query.accountIds.isEmpty ||
            transaction.ledgerEntries.any(
              (entry) => query.accountIds.contains(entry.accountId),
            )) &&
        (query.tagIds.isEmpty ||
            transaction.tagIds.any((tagId) => query.tagIds.contains(tagId))) &&
        (query.effectiveFrom == null ||
            !transaction.effectiveAt.isBefore(query.effectiveFrom!)) &&
        (query.effectiveUntil == null ||
            transaction.effectiveAt.isBefore(query.effectiveUntil!));
  }

  /// Executes a persistence operation and translates persistence exceptions.
  Future<Result<T, TransactionFailure>>
  guardPersistenceOperation<T extends Object?>(
    Future<Result<T, TransactionFailure>> Function() operation,
  ) => persistenceGuard<T>(operation);

  /// Executes [operation] through the shared persistence guard.
  Future<Result<T, TransactionFailure>> persistenceGuard<T extends Object?>(
    Future<Result<T, TransactionFailure>> Function() operation,
  ) {
    return persistence.guardPersistenceOperation<T, TransactionFailure>(
      operation: operation,
      persistenceFailure: (message) =>
          TransactionRepositoryFailure(message: message),
      failureMessage: 'Transaction persistence operation failed.',
    );
  }

  /// Creates the standard transaction-not-found failure for [id].
  static TransactionNotFoundFailure _notFound(TransactionId id) {
    return TransactionNotFoundFailure(
      message:
          'Transaction ID was not found: '
          '${id.value}',
    );
  }
}
