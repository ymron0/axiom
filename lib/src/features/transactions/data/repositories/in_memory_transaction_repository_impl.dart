import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/budget_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:fixtures/fixtures.dart';
import 'package:fixtures/types/transactions.dart';

/// Stores transaction aggregates in memory.
///
/// When no seed is supplied, the repository loads the external transaction
/// fixtures. Iteration order is persistence insertion order.
final class InMemoryTransactionRepositoryImpl
    implements TransactionRepository {
  /// Creates a repository seeded with [initialTransactions].
  ///
  /// Throws [ArgumentError] when the seed contains duplicate transaction IDs.
  InMemoryTransactionRepositoryImpl({
    Iterable<Transaction>? initialTransactions,
  }) : _transactions = _validatedSeed(
         initialTransactions ?? transactionsFixtures.map(_fromFixture),
       );

  final Map<TransactionId, Transaction> _transactions;

  static Map<TransactionId, Transaction> _validatedSeed(
    Iterable<Transaction> transactions,
  ) {
    final result = <TransactionId, Transaction>{};

    for (final transaction in transactions) {
      if (transaction.isDeleted) {
        throw ArgumentError(
          'Deleted transaction cannot be seeded: ${transaction.id.value}',
        );
      }
      if (result.containsKey(transaction.id)) {
        throw ArgumentError(
          'Transaction ID is duplicated: ${transaction.id.value}',
        );
      }
      result[transaction.id] = transaction;
    }

    return result;
  }

  @override
  Future<Result<void, TransactionFailure>> create(
    Transaction transaction,
  ) async {
    if (transaction.isDeleted) {
      return TransactionAlreadyDeletedFailure(
        message: 'Deleted transaction cannot be created: '
            '${transaction.id.value}',
      );
    }
    if (_transactions.containsKey(transaction.id)) {
      return TransactionAlreadyExistsFailure(
        message: 'Transaction ID already exists: ${transaction.id.value}',
      );
    }

    _transactions[transaction.id] = transaction;
    return const Success(null);
  }

  @override
  Future<Result<void, TransactionFailure>> createAll(
    List<Transaction> transactions,
  ) async {
    for (final transaction in transactions) {
      if (transaction.isDeleted) {
        return TransactionAlreadyDeletedFailure(
          message: 'Deleted transaction cannot be created: '
              '${transaction.id.value}',
        );
      }
    }

    final requestedIds = <TransactionId>{};
    for (final transaction in transactions) {
      if (!requestedIds.add(transaction.id)) {
        return TransactionAlreadyExistsFailure(
          message: 'Transaction ID is duplicated: ${transaction.id.value}',
        );
      }
      if (_transactions.containsKey(transaction.id)) {
        return TransactionAlreadyExistsFailure(
          message: 'Transaction ID already exists: ${transaction.id.value}',
        );
      }
    }

    for (final transaction in transactions) {
      _transactions[transaction.id] = transaction;
    }
    return const Success(null);
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>> getAll() async {
    return Success(List.unmodifiable(_transactions.values));
  }

  @override
  Future<Result<Transaction?, TransactionFailure>> getById(
    TransactionId id,
  ) async {
    return Success(_transactions[id]);
  }

  @override
  Future<Result<List<Transaction>, TransactionFailure>> query(
    TransactionQuery query,
  ) async {
    final matches = _transactions.values.where((transaction) {
      return (query.kinds.isEmpty || query.kinds.contains(transaction.kind)) &&
          (query.states.isEmpty ||
              query.states.contains(transaction.state)) &&
          (query.merchantIds.isEmpty ||
              query.merchantIds.contains(transaction.merchantId)) &&
          (query.accountIds.isEmpty ||
              transaction.ledgerEntries.any(
                (entry) => query.accountIds.contains(entry.accountId),
              ));
    }).toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<void, TransactionFailure>> update(
    Transaction transaction,
  ) async {
    if (transaction.isDeleted) {
      return TransactionAlreadyDeletedFailure(
        message: 'Deleted transaction cannot be updated: '
            '${transaction.id.value}',
      );
    }
    final stored = _transactions[transaction.id];
    if (stored == null) {
      return _notFound(transaction.id);
    }
    if (transaction.entityVersion != stored.entityVersion) {
      return TransactionVersionConflictFailure(
        message: 'Transaction version conflicts with the stored version: '
            '${transaction.id.value}',
      );
    }

    _transactions[transaction.id] = transaction;
    return const Success(null);
  }

  @override
  Future<Result<void, TransactionFailure>> delete(TransactionId id) async {
    if (!_transactions.containsKey(id)) {
      return _notFound(id);
    }

    _transactions.remove(id);
    return const Success(null);
  }

  @override
  Future<Result<void, TransactionFailure>> restore(
    Transaction transaction,
  ) async {
    if (!transaction.isDeleted) {
      return TransactionNotDeletedFailure(
        message: 'Transaction is not deleted: ${transaction.id.value}',
      );
    }
    if (_transactions.containsKey(transaction.id)) {
      return TransactionAlreadyExistsFailure(
        message: 'Transaction ID already exists: ${transaction.id.value}',
      );
    }

    _transactions[transaction.id] = transaction.copyWith(deletedAt: null);
    return const Success(null);
  }

  static TransactionNotFoundFailure _notFound(TransactionId id) {
    return TransactionNotFoundFailure(
      message: 'Transaction ID was not found: ${id.value}',
    );
  }

  static Transaction _fromFixture(TransactionFixture fixture) {
    return Transaction(
      id: TransactionId.fromString(fixture.id),
      kind: TransactionKind.values.byName(fixture.kind),
      merchantId: MerchantId.fromString(fixture.merchantId),
      description: fixture.description,
      note: fixture.note,
      state: TransactionState.values.byName(fixture.state),
      deletedAt: null,
      splits: fixture.splits.map(_splitFromFixture).toList(growable: false),
      ledgerEntries: fixture.ledgerEntries
          .map(_ledgerEntryFromFixture)
          .toList(growable: false),
      entityVersion: fixture.entityVersion,
      createdAt: fixture.createdAt,
      modifiedAt: fixture.modifiedAt,
    );
  }

  static LedgerEntry _ledgerEntryFromFixture(LedgerEntryFixture fixture) {
    return LedgerEntry(
      accountId: AccountId.fromString(fixture.accountId),
      transactionAmount: _amountFromFixture(fixture.transactionAmount),
      accountAmount: _amountFromFixture(fixture.accountAmount),
      valuationAmount: _amountFromFixture(fixture.valuationAmount),
      role: LedgerEntryRole.values.byName(fixture.role),
    );
  }

  static TransactionSplit _splitFromFixture(TransactionSplitFixture fixture) {
    return TransactionSplit(
      transactionAmount: _amountFromFixture(fixture.transactionAmount),
      valuationAmount: _amountFromFixture(fixture.valuationAmount),
      budgetId: fixture.budgetId == null
          ? null
          : BudgetId.fromString(fixture.budgetId!),
      categoryId: fixture.categoryId == null
          ? null
          : CategoryId.fromString(fixture.categoryId!),
      jarId: fixture.jarId == null ? null : JarId.fromString(fixture.jarId!),
    );
  }

  static AssetAmount _amountFromFixture(AssetAmountFixture fixture) {
    return AssetAmount(
      assetId: AssetId.fromString(fixture.assetId),
      amount: Decimal.parse(fixture.amount),
      direction: AssetAmountDirection.values.byName(fixture.direction),
    );
  }
}
