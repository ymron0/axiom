import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart'
    as persistence;
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/data/failures/transaction_persistence_failure.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:sembast/sembast.dart' hide Transaction;

/// Persists transaction aggregates in the configured Sembast database.
///
/// This implementation preserves the complete [TransactionRepository] contract:
///
/// - only active transactions are stored;
/// - transaction identifiers are Sembast record keys;
/// - batch creation is atomic;
/// - deletion physically removes records;
/// - restoration inserts an active copy of a caller-retained deleted snapshot;
/// - entity versions are preserved rather than incremented by updates;
/// - returned collections are immutable; and
/// - transaction iteration preserves persistence insertion order.
///
/// Persisted maps are always reconstructed through
/// [TransactionPersistenceModel]. Corrupt records therefore fail through the
/// typed persistence boundary rather than leaking storage representation errors
/// into the domain or application layers.
final class SembastTransactionRepositoryImpl implements TransactionRepository {
  /// Creates a transaction repository using an already-open [database].
  const SembastTransactionRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.transactions;

  final Database _database;

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
        // Validate the entire batch before writing anything.
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

        // All validation has completed. Writes now occur atomically inside the
        // same Sembast transaction.
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

        // Reconstruct the complete aggregate before replacement so structurally
        // valid but domain-invalid persisted state is still treated as corrupt.
        final storedTransaction = storedModel.toEntity();

        if (transaction.entityVersion != storedTransaction.entityVersion) {
          return TransactionVersionConflictFailure(
            message:
                'Transaction version conflicts with the stored version: '
                '${transaction.id.value}',
          );
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

  /// Reads every transaction in persistence insertion order.
  ///
  /// Every record is reconstructed through the persistence model before being
  /// returned. Consequently, malformed or domain-invalid records cannot be
  /// silently skipped by higher-level queries.
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

  /// Allocates the next persistence insertion position.
  ///
  /// The value is allocated inside the same Sembast transaction as the
  /// corresponding write, so concurrent repository operations cannot allocate
  /// the same position.
  ///
  /// Only persistence-order metadata is read here. Complete aggregate decoding
  /// is unnecessary for sequence allocation.
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

  /// Returns immutable transactions satisfying [matches].
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

  /// Determines whether at least one persisted transaction satisfies [matches].
  ///
  /// The complete persisted aggregate is decoded before matching. This is
  /// intentional for deletion-safety queries: corrupt transaction data should
  /// produce a persistence failure rather than accidentally allowing a
  /// referenced account, merchant, category, or jar to be deleted.
  Future<Result<bool, TransactionFailure>> _existsWhere(
    bool Function(Transaction transaction) matches,
  ) {
    return guardPersistenceOperation(() async {
      final transactions = await _readAll(_database);

      return Success(transactions.any(matches));
    });
  }

  /// Applies the semantics defined by [TransactionQuery].
  static bool _matchesQuery(Transaction transaction, TransactionQuery query) {
    return (query.kinds.isEmpty || query.kinds.contains(transaction.kind)) &&
        (query.states.isEmpty || query.states.contains(transaction.state)) &&
        (query.merchantIds.isEmpty ||
            query.merchantIds.contains(transaction.merchantId)) &&
        (query.accountIds.isEmpty ||
            transaction.ledgerEntries.any(
              (entry) => query.accountIds.contains(entry.accountId),
            )) &&
        (query.effectiveFrom == null ||
            !transaction.effectiveAt.isBefore(query.effectiveFrom!)) &&
        (query.effectiveUntil == null ||
            transaction.effectiveAt.isBefore(query.effectiveUntil!));
  }

  Future<Result<T, TransactionFailure>>
  guardPersistenceOperation<T extends Object?>(
    Future<Result<T, TransactionFailure>> Function() operation,
  ) => persistenceGuard<T>(operation);

  Future<Result<T, TransactionFailure>> persistenceGuard<T extends Object?>(
    Future<Result<T, TransactionFailure>> Function() operation,
  ) {
    return persistence.guardPersistenceOperation<T, TransactionFailure>(
      operation: operation,
      persistenceFailure: (message) =>
          TransactionPersistenceFailure(message: message),
      failureMessage: 'Transaction persistence operation failed.',
    );
  }

  static TransactionNotFoundFailure _notFound(TransactionId id) {
    return TransactionNotFoundFailure(
      message:
          'Transaction ID was not found: '
          '${id.value}',
    );
  }
}
