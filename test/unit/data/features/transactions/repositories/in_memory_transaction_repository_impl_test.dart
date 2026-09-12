import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  InMemoryTransactionRepositoryImpl createRepository() => InMemoryTransactionRepositoryImpl(initialTransactions: const []);
  final createdAt = DateTime.utc(2026, 1, 1);
  final deletedAt = DateTime.utc(2026, 1, 2);

  Transaction transactionFixture({
    required String id,
    String? description = 'transaction description',
    String? note = 'transaction note',
    TransactionKind kind = TransactionKind.expense,
    String merchantId = 'self',
    TransactionState state = TransactionState.actual,
    String accountId = 'account-eur-checking',
    DateTime? deletedAt,
    int entityVersion = 1,
    DateTime? modifiedAt,
  }) {
    final amount = AssetAmount(
      assetId: AssetId.fromString('asset-eur'),
      amount: Decimal.zero,
      direction: kind == TransactionKind.income
          ? AssetAmountDirection.incoming
          : AssetAmountDirection.outgoing,
    );

    return Transaction(
      id: TransactionId.fromString(id),
      kind: kind,
      merchantId: merchantId == 'self'
          ? MerchantId.self
          : MerchantId.fromString(merchantId),
      description: description,
      note: note,
      state: state,
      deletedAt: deletedAt,
      splits: const [],
      ledgerEntries: [
        LedgerEntry(
          accountId: AccountId.fromString(accountId),
          transactionAmount: amount,
          accountAmount: amount,
          valuationAmount: amount,
          role: LedgerEntryRole.primary,
        ),
      ],
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? createdAt,
      entityVersion: entityVersion,
    );
  }

  group('InMemoryTransactionRepositoryImpl', () {
    group('initial state', () {
      test('starts empty', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isEmpty);
      });

      test('loads the external transaction fixtures when no seed is supplied', () async {
        // Given
        final repository = InMemoryTransactionRepositoryImpl();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNotEmpty);
      });

      test('stores valid supplied seed transactions in order', () async {
        // Given
        final first = transactionFixture(id: 'seed-first');
        final second = transactionFixture(id: 'seed-second');
        final repository = InMemoryTransactionRepositoryImpl(
          initialTransactions: [first, second],
        );

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('rejects a deleted transaction in the supplied seed', () {
        // Given
        final deleted = transactionFixture(
          id: 'seed-deleted',
          deletedAt: deletedAt,
        );

        // When / Then
        expect(
          () => InMemoryTransactionRepositoryImpl(
            initialTransactions: [deleted],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects duplicate transaction IDs in the supplied seed', () {
        // Given
        final first = transactionFixture(id: 'seed-duplicate');
        final duplicate = transactionFixture(
          id: first.id.value,
          description: 'duplicate transaction',
        );

        // When / Then
        expect(
          () => InMemoryTransactionRepositoryImpl(
            initialTransactions: [first, duplicate],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('create', () {
      test('stores a transaction and preserves its entity version', () async {
        // Given
        final repository = createRepository();
        final transaction = transactionFixture(
          id: 'create-transaction',
          entityVersion: 7,
        );

        // When
        final result = await repository.create(transaction);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getById(transaction.id)).valueOrNull;
        expect(stored, same(transaction));
        expect(stored!.entityVersion, 7);
      });

      test('rejects a duplicate identity without replacing the original', () async {
        // Given
        final repository = createRepository();
        final original = transactionFixture(id: 'duplicate-transaction');
        final duplicate = transactionFixture(
          id: original.id.value,
          description: 'replacement',
        );
        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('accepts null description and note', () async {
        // Given
        final repository = createRepository();
        final transaction = transactionFixture(
          id: 'nullable-text-transaction',
          description: null,
          note: null,
        );

        // When
        final result = await repository.create(transaction);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getById(transaction.id)).valueOrNull;
        expect(stored?.description, isNull);
        expect(stored?.note, isNull);
      });

      test('rejects an empty description and note when constructing a transaction', () {
        // Given / When / Then
        expect(
          () => transactionFixture(
            id: 'empty-description-transaction',
            description: '',
          ),
          throwsArgumentError,
        );
        expect(
          () => transactionFixture(
            id: 'empty-note-transaction',
            note: '',
          ),
          throwsArgumentError,
        );
      });

      test('rejects a deleted transaction', () async {
        // Given
        final repository = createRepository();
        final deleted = transactionFixture(
          id: 'create-deleted-transaction',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.create(deleted);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyDeletedFailure>());
        expect((await repository.getById(deleted.id)).valueOrNull, isNull);
      });
    });

    group('createAll', () {
      test('stores every transaction in request order', () async {
        // Given
        final repository = createRepository();
        final first = transactionFixture(
          id: 'create-all-first',
          entityVersion: 2,
        );
        final second = transactionFixture(
          id: 'create-all-second',
          entityVersion: 3,
        );

        // When
        final result = await repository.createAll([first, second]);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getAll()).valueOrNull!;
        expect(stored, [same(first), same(second)]);
        expect(stored.map((transaction) => transaction.entityVersion), [2, 3]);
      });

      test('rejects a deleted transaction without partial mutation', () async {
        // Given
        final repository = createRepository();
        final active = transactionFixture(id: 'create-all-active');
        final deleted = transactionFixture(
          id: 'create-all-deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.createAll([active, deleted]);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyDeletedFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('rejects duplicate IDs within the request without partial mutation', () async {
        // Given
        final repository = createRepository();
        final first = transactionFixture(id: 'create-all-duplicate');
        final duplicate = transactionFixture(
          id: first.id.value,
          description: 'duplicate transaction',
        );

        // When
        final result = await repository.createAll([first, duplicate]);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyExistsFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('rejects an ID already stored without partial mutation', () async {
        // Given
        final repository = createRepository();
        final original = transactionFixture(id: 'create-all-existing');
        final duplicate = transactionFixture(
          id: original.id.value,
          description: 'replacement transaction',
        );
        await repository.create(original);

        // When
        final result = await repository.createAll([duplicate]);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('getById', () {
      test('returns the transaction for an existing ID', () async {
        // Given
        final repository = createRepository();
        final transaction = transactionFixture(id: 'get-by-id-transaction');
        await repository.create(transaction);

        // When
        final result = await repository.getById(transaction.id);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, same(transaction));
      });

      test('returns a successful null result for a missing ID', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.getById(
          TransactionId.fromString('missing-transaction'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('getAll', () {
      test('returns all stored transactions in insertion order', () async {
        // Given
        final repository = createRepository();
        final first = transactionFixture(id: 'get-all-first');
        final second = transactionFixture(id: 'get-all-second');
        await repository.create(second);
        await repository.create(first);

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(second), same(first)]);
      });
    });

    group('query', () {
      test('applies AND across criteria and OR within each criterion', () async {
        // Given
        final repository = createRepository();
        final expense = transactionFixture(
          id: 'query-expense',
          merchantId: 'merchant-grocery',
          accountId: 'account-eur-checking',
        );
        final income = transactionFixture(
          id: 'query-income',
          kind: TransactionKind.income,
          state: TransactionState.planned,
          merchantId: 'merchant-employer',
          accountId: 'account-chf-checking',
        );
        final unrelated = transactionFixture(
          id: 'query-unrelated',
          merchantId: 'merchant-other',
          accountId: 'account-chf-checking',
        );
        await repository.createAll([expense, income, unrelated]);

        // When
        final result = await repository.query(
          TransactionQuery(
            kinds: {TransactionKind.expense, TransactionKind.income},
            states: {TransactionState.actual, TransactionState.planned},
            merchantIds: {
              MerchantId.fromString('merchant-grocery'),
              MerchantId.fromString('merchant-employer'),
            },
            accountIds: {AccountId.fromString('account-chf-checking')},
          ),
        );

        // Then
        expect(result.valueOrNull, [same(income)]);
      });

      test('matches transactions affecting a requested account', () async {
        // Given
        final repository = createRepository();
        final first = transactionFixture(
          id: 'query-account-first',
          accountId: 'account-eur-checking',
        );
        final second = transactionFixture(
          id: 'query-account-second',
          accountId: 'account-chf-checking',
        );
        await repository.createAll([first, second]);

        // When
        final result = await repository.query(
          TransactionQuery(
            accountIds: {AccountId.fromString('account-chf-checking')},
          ),
        );

        // Then
        expect(result.valueOrNull, [same(second)]);
      });

      test('returns all transactions for an unrestricted query', () async {
        // Given
        final repository = createRepository();
        final first = transactionFixture(id: 'query-all-first');
        final second = transactionFixture(id: 'query-all-second');
        await repository.createAll([first, second]);

        // When
        final result = await repository.query(TransactionQuery());

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });
    });

    group('update', () {
      test('replaces an existing transaction without changing its entity version', () async {
        // Given
        final repository = createRepository();
        final original = transactionFixture(
          id: 'update-transaction',
          entityVersion: 4,
        );
        final replacement = transactionFixture(
          id: original.id.value,
          description: 'updated description',
          entityVersion: original.entityVersion,
          modifiedAt: DateTime.utc(2026, 1, 2),
        );
        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getById(original.id)).valueOrNull;
        expect(stored, same(replacement));
        expect(stored!.entityVersion, 4);
      });

      test('rejects an entity version conflict without mutation', () async {
        // Given
        final repository = createRepository();
        final original = transactionFixture(
          id: 'version-conflict-transaction',
          entityVersion: 4,
        );
        final conflicting = transactionFixture(
          id: original.id.value,
          entityVersion: 5,
          description: 'conflicting update',
        );
        await repository.create(original);

        // When
        final result = await repository.update(conflicting);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionVersionConflictFailure>(),
        );
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('rejects a deleted transaction without mutation', () async {
        // Given
        final repository = createRepository();
        final original = transactionFixture(id: 'update-deleted-original');
        final deleted = transactionFixture(
          id: original.id.value,
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.update(deleted);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyDeletedFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('returns TransactionNotFoundFailure for a missing transaction', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.update(
          transactionFixture(id: 'update-missing-transaction'),
        );

        // Then
        expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
      });
    });

    group('delete', () {
      test('removes an existing transaction', () async {
        // Given
        final repository = createRepository();
        final transaction = transactionFixture(id: 'delete-transaction');
        await repository.create(transaction);

        // When
        final result = await repository.delete(transaction.id);

        // Then
        expect(result.isSuccess, isTrue);
        expect((await repository.getById(transaction.id)).valueOrNull, isNull);
      });

      test('returns TransactionNotFoundFailure for a missing ID', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.delete(
          TransactionId.fromString('delete-missing-transaction'),
        );

        // Then
        expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
      });
    });

    group('restore', () {
      test('restores only a deleted transaction and preserves its entity version', () async {
        // Given
        final repository = createRepository();
        final active = transactionFixture(
          id: 'restore-transaction',
          entityVersion: 9,
        );
        final deleted = transactionFixture(
          id: active.id.value,
          entityVersion: active.entityVersion,
          deletedAt: deletedAt,
        );
        await repository.create(active);
        await repository.delete(active.id);

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.isSuccess, isTrue);
        final restored = (await repository.getById(active.id)).valueOrNull;
        expect(restored?.isDeleted, isFalse);
        expect(restored?.entityVersion, 9);
      });

      test('rejects restoring a deleted transaction over an existing ID', () async {
        // Given
        final repository = createRepository();
        final active = transactionFixture(id: 'restore-existing-transaction');
        final deleted = transactionFixture(
          id: active.id.value,
          deletedAt: deletedAt,
        );
        await repository.create(active);

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.failureOrNull, isA<TransactionAlreadyExistsFailure>());
        expect((await repository.getById(active.id)).valueOrNull, same(active));
      });

      test('rejects an active transaction', () async {
        // Given
        final repository = createRepository();
        final active = transactionFixture(id: 'restore-active-transaction');

        // When
        final result = await repository.restore(active);

        // Then
        expect(result.failureOrNull, isA<TransactionNotDeletedFailure>());
        expect((await repository.getById(active.id)).valueOrNull, isNull);
      });
    });
  });
}
