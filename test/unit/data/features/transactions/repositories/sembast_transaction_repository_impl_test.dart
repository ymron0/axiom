@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/data/failures/transaction_persistence_failure.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_exceeds_available_amount_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:sembast/sembast.dart' hide Transaction;
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late TransactionRepository repository;

  final deletedAt = DateTime.utc(2026, 1, 3);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastTransactionRepositoryImpl(database: database);
  });

  group('SembastTransactionRepositoryImpl', () {
    group('create', () {
      test('persists a transaction and preserves entityVersion', () async {
        // Given
        final transaction = _transaction(
          id: 'create',
          entityVersion: 7,
        );

        // When
        final result = await repository.create(transaction);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(
          transaction.id,
        )).valueOrNull!;

        expect(stored.id, transaction.id);
        expect(stored.entityVersion, 7);
        expect(stored.description, transaction.description);
      });

      test('rejects duplicate identity without replacement', () async {
        // Given
        final original = _transaction(
          id: 'duplicate',
          description: 'Original',
        );

        final duplicate = _transaction(
          id: original.id.value,
          description: 'Replacement',
        );

        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyExistsFailure>(),
        );

        expect(
          (await repository.getById(original.id)).valueOrNull?.description,
          'Original',
        );
      });

      test('rejects a deleted transaction', () async {
        // Given
        final deleted = _transaction(
          id: 'create-deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.create(deleted);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyDeletedFailure>(),
        );

        expect(
          (await repository.getById(deleted.id)).valueOrNull,
          isNull,
        );
      });

      test('rejects an offset transaction', () async {
        // Given
        final offset = _offsetTransaction(
          id: 'create-offset',
          originalId: 'original',
          amount: Decimal.fromInt(10),
        );

        // When
        final result = await repository.create(offset);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionOffsetValidationFailure>(),
        );

        expect(
          (await repository.getById(offset.id)).valueOrNull,
          isNull,
        );
      });
    });

    group('createAll', () {
      test('persists all transactions in request order', () async {
        // Given
        final first = _transaction(id: 'batch-first');
        final second = _transaction(id: 'batch-second');

        // When
        final result = await repository.createAll([first, second]);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getAll()).valueOrNull!;

        expect(
          stored.map((transaction) => transaction.id),
          [first.id, second.id],
        );
      });

      test('succeeds for an empty batch', () async {
        // When
        final result = await repository.createAll(const []);

        // Then
        expect(result.isSuccess, isTrue);
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('is atomic when one transaction is deleted', () async {
        // Given
        final active = _transaction(id: 'batch-active');

        final deleted = _transaction(
          id: 'batch-deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.createAll([active, deleted]);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyDeletedFailure>(),
        );

        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('is atomic for duplicate request IDs', () async {
        // Given
        final first = _transaction(
          id: 'batch-duplicate',
          description: 'First',
        );

        final duplicate = _transaction(
          id: first.id.value,
          description: 'Duplicate',
        );

        // When
        final result = await repository.createAll([first, duplicate]);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyExistsFailure>(),
        );

        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('is atomic when one ID already exists', () async {
        // Given
        final existing = _transaction(id: 'batch-existing');
        final fresh = _transaction(id: 'batch-fresh');

        await repository.create(existing);

        // When
        final result = await repository.createAll([fresh, existing]);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyExistsFailure>(),
        );

        expect(
          (await repository.getById(fresh.id)).valueOrNull,
          isNull,
        );
      });

      test('rejects a batch containing an offset transaction', () async {
        // Given
        final normal = _transaction(id: 'batch-normal');

        final offset = _offsetTransaction(
          id: 'batch-offset',
          originalId: 'original',
          amount: Decimal.fromInt(10),
        );

        // When
        final result = await repository.createAll([normal, offset]);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionOffsetValidationFailure>(),
        );

        expect((await repository.getAll()).valueOrNull, isEmpty);
      });
    });

    group('createOffset', () {
      test('creates a valid offset transaction', () async {
        // Given
        final original = _transaction(
          id: 'offset-original',
          amount: Decimal.fromInt(100),
        );

        final offset = _offsetTransaction(
          id: 'offset-valid',
          originalId: original.id.value,
          amount: Decimal.fromInt(50),
        );

        await repository.create(original);

        // When
        final result = await repository.createOffset(offset);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(offset.id)).valueOrNull!;

        expect(stored.id, offset.id);
        expect(stored.isOffset, isTrue);
        expect(
          stored.offset?.originalTransactionId,
          original.id,
        );
        expect(
          stored.offset?.kind,
          TransactionOffsetKind.reimbursement,
        );
      });

      test('rejects a deleted offset transaction', () async {
        // Given
        final offset = _offsetTransaction(
          id: 'offset-deleted',
          originalId: 'original',
          amount: Decimal.fromInt(10),
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.createOffset(offset);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyDeletedFailure>(),
        );
      });

      test('rejects a transaction without an offset relationship', () async {
        // Given
        final transaction = _transaction(
          id: 'not-an-offset',
          amount: Decimal.fromInt(10),
        );

        // When
        final result = await repository.createOffset(transaction);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionOffsetValidationFailure>(),
        );
      });

      test('returns not-found when original transaction is missing', () async {
        // Given
        final offset = _offsetTransaction(
          id: 'missing-original-offset',
          originalId: 'missing-original',
          amount: Decimal.fromInt(10),
        );

        // When
        final result = await repository.createOffset(offset);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionNotFoundFailure>(),
        );

        expect(
          (await repository.getById(offset.id)).valueOrNull,
          isNull,
        );
      });

      test('rejects duplicate transaction identity', () async {
        // Given
        final original = _transaction(
          id: 'duplicate-offset-original',
          amount: Decimal.fromInt(100),
        );

        final existing = _transaction(
          id: 'duplicate-offset-id',
          amount: Decimal.fromInt(1),
        );

        final offset = _offsetTransaction(
          id: existing.id.value,
          originalId: original.id.value,
          amount: Decimal.fromInt(10),
        );

        await repository.createAll([original, existing]);

        // When
        final result = await repository.createOffset(offset);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionAlreadyExistsFailure>(),
        );
      });

      test('allows cumulative offsets equal to original amount', () async {
        // Given
        final original = _transaction(
          id: 'exact-original',
          amount: Decimal.fromInt(100),
        );

        final first = _offsetTransaction(
          id: 'exact-first',
          originalId: original.id.value,
          amount: Decimal.fromInt(60),
          offsetKind: TransactionOffsetKind.reimbursement,
        );

        final second = _offsetTransaction(
          id: 'exact-second',
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
          offsetKind: TransactionOffsetKind.refund,
        );

        await repository.create(original);
        await repository.createOffset(first);

        // When
        final result = await repository.createOffset(second);

        // Then
        expect(result.isSuccess, isTrue);

        final offsets = (await repository.getOffsetsForTransaction(
          original.id,
        )).valueOrNull!;

        expect(offsets, hasLength(2));
      });

      test('rejects cumulative offsets above original amount', () async {
        // Given
        final original = _transaction(
          id: 'over-original',
          amount: Decimal.fromInt(100),
        );

        final first = _offsetTransaction(
          id: 'over-first',
          originalId: original.id.value,
          amount: Decimal.fromInt(60),
        );

        final second = _offsetTransaction(
          id: 'over-second',
          originalId: original.id.value,
          amount: Decimal.fromInt(50),
        );

        await repository.create(original);
        await repository.createOffset(first);

        // When
        final result = await repository.createOffset(second);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionOffsetExceedsAvailableAmountFailure>(),
        );

        final offsets = (await repository.getOffsetsForTransaction(
          original.id,
        )).valueOrNull!;

        expect(offsets, hasLength(1));
        expect(offsets.single.id, first.id);

        expect(
          (await repository.getById(second.id)).valueOrNull,
          isNull,
        );
      });

      test('supports allocated offsets using original allocation', () async {
        // Given
        final categoryId = CategoryId.fromString('restaurants');

        final original = _transaction(
          id: 'allocated-original',
          amount: Decimal.fromInt(100),
          splits: [
            _split(
              categoryId: categoryId.value,
              amount: Decimal.fromInt(100),
            ),
          ],
        );

        final offset = _offsetTransaction(
          id: 'allocated-offset',
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
          categoryId: categoryId.value,
        );

        await repository.create(original);

        // When
        final result = await repository.createOffset(offset);

        // Then
        expect(result.isSuccess, isTrue);
      });
    });

    group('basic queries', () {
      test('getAll preserves insertion order and is immutable', () async {
        // Given
        final first = _transaction(id: 'all-first');
        final second = _transaction(id: 'all-second');

        await repository.create(second);
        await repository.create(first);

        // When
        final transactions = (await repository.getAll()).valueOrNull!;

        // Then
        expect(
          transactions.map((transaction) => transaction.id),
          [second.id, first.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns successful null for missing ID', () async {
        // When
        final result = await repository.getById(
          TransactionId.fromString('missing'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('offset queries', () {
      test('returns offsets in persistence insertion order', () async {
        // Given
        final original = _transaction(
          id: 'query-offset-original',
          amount: Decimal.fromInt(100),
        );

        final otherOriginal = _transaction(
          id: 'query-offset-other-original',
          amount: Decimal.fromInt(100),
        );

        final first = _offsetTransaction(
          id: 'query-offset-first',
          originalId: original.id.value,
          amount: Decimal.fromInt(20),
        );

        final unrelated = _offsetTransaction(
          id: 'query-offset-unrelated',
          originalId: otherOriginal.id.value,
          amount: Decimal.fromInt(10),
        );

        final second = _offsetTransaction(
          id: 'query-offset-second',
          originalId: original.id.value,
          amount: Decimal.fromInt(30),
        );

        await repository.createAll([original, otherOriginal]);
        await repository.createOffset(first);
        await repository.createOffset(unrelated);
        await repository.createOffset(second);

        // When
        final offsets = (await repository.getOffsetsForTransaction(
          original.id,
        )).valueOrNull!;

        // Then
        expect(
          offsets.map((transaction) => transaction.id),
          [first.id, second.id],
        );

        expect(
          () => offsets.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns immutable empty list when no offsets exist', () async {
        // Given
        final original = _transaction(
          id: 'query-offset-empty',
          amount: Decimal.fromInt(100),
        );

        await repository.create(original);

        // When
        final offsets = (await repository.getOffsetsForTransaction(
          original.id,
        )).valueOrNull!;

        // Then
        expect(offsets, isEmpty);

        expect(
          () => offsets.clear(),
          throwsUnsupportedError,
        );
      });
    });

    group('relationship queries', () {
      test('returns ledger entries in transaction and entry order', () async {
        // Given
        final firstMatching = _ledgerEntry('account-target');

        final unrelated = _ledgerEntry(
          'account-other',
          role: LedgerEntryRole.fee,
        );

        final secondMatching = _ledgerEntry('account-target');

        final firstTransaction = _transaction(
          id: 'ledger-first',
          ledgerEntries: [firstMatching, unrelated],
        );

        final secondTransaction = _transaction(
          id: 'ledger-second',
          ledgerEntries: [secondMatching],
        );

        await repository.createAll([
          firstTransaction,
          secondTransaction,
        ]);

        // When
        final entries = (await repository.getLedgerEntriesByAccountId(
          AccountId.fromString('account-target'),
        )).valueOrNull!;

        // Then
        expect(entries, hasLength(2));
        expect(entries[0].accountId, firstMatching.accountId);
        expect(entries[0].role, firstMatching.role);
        expect(entries[1].accountId, secondMatching.accountId);

        expect(
          () => entries.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns transactions by account in insertion order', () async {
        // Given
        final first = _transaction(
          id: 'account-first',
          accountId: 'account-target',
        );

        final unrelated = _transaction(
          id: 'account-other',
          accountId: 'account-other',
        );

        final second = _transaction(
          id: 'account-second',
          accountId: 'account-target',
        );

        await repository.createAll([first, unrelated, second]);

        // When
        final transactions = (await repository.getTransactionsByAccountId(
          AccountId.fromString('account-target'),
        )).valueOrNull!;

        // Then
        expect(
          transactions.map((transaction) => transaction.id),
          [first.id, second.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns transactions by merchant', () async {
        // Given
        final matching = _transaction(
          id: 'merchant-match',
          merchantId: 'merchant-target',
        );

        final unrelated = _transaction(
          id: 'merchant-other',
          merchantId: 'merchant-other',
        );

        await repository.createAll([matching, unrelated]);

        // When
        final transactions = (await repository.getTransactionsByMerchantId(
          MerchantId.fromString('merchant-target'),
        )).valueOrNull!;

        // Then
        expect(
          transactions.map((transaction) => transaction.id),
          [matching.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns transactions by category allocation', () async {
        // Given
        final matching = _transaction(
          id: 'category-match',
          splits: [
            _split(categoryId: 'category-target'),
          ],
        );

        final unrelated = _transaction(
          id: 'category-other',
          splits: [
            _split(categoryId: 'category-other'),
          ],
        );

        await repository.createAll([matching, unrelated]);

        // When
        final transactions = (await repository.getTransactionsByCategoryId(
          CategoryId.fromString('category-target'),
        )).valueOrNull!;

        // Then
        expect(
          transactions.map((transaction) => transaction.id),
          [matching.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns transactions by jar allocation', () async {
        // Given
        final matching = _transaction(
          id: 'jar-match',
          splits: [
            _split(jarId: 'jar-target'),
          ],
        );

        final unrelated = _transaction(
          id: 'jar-other',
          splits: [
            _split(jarId: 'jar-other'),
          ],
        );

        await repository.createAll([matching, unrelated]);

        // When
        final transactions = (await repository.getTransactionsByJarId(
          JarId.fromString('jar-target'),
        )).valueOrNull!;

        // Then
        expect(
          transactions.map((transaction) => transaction.id),
          [matching.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });

      test('returns immutable empty relationship results', () async {
        // When
        final transactions = (await repository.getTransactionsByAccountId(
          AccountId.fromString('missing-account'),
        )).valueOrNull!;

        // Then
        expect(transactions, isEmpty);

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });
    });

    group('relationship existence checks', () {
      test('returns true for referenced IDs', () async {
        // Given
        final transaction = _transaction(
          id: 'exists',
          merchantId: 'merchant-target',
          accountId: 'account-target',
          splits: [
            _split(
              categoryId: 'category-target',
              jarId: 'jar-target',
            ),
          ],
        );

        await repository.create(transaction);

        // When / Then
        expect(
          (await repository.existsByAccountId(
            AccountId.fromString('account-target'),
          )).valueOrNull,
          isTrue,
        );

        expect(
          (await repository.existsByMerchantId(
            MerchantId.fromString('merchant-target'),
          )).valueOrNull,
          isTrue,
        );

        expect(
          (await repository.existsByCategoryId(
            CategoryId.fromString('category-target'),
          )).valueOrNull,
          isTrue,
        );

        expect(
          (await repository.existsByJarId(
            JarId.fromString('jar-target'),
          )).valueOrNull,
          isTrue,
        );
      });

      test('returns false for unreferenced IDs', () async {
        expect(
          (await repository.existsByAccountId(
            AccountId.fromString('missing-account'),
          )).valueOrNull,
          isFalse,
        );

        expect(
          (await repository.existsByMerchantId(
            MerchantId.fromString('missing-merchant'),
          )).valueOrNull,
          isFalse,
        );

        expect(
          (await repository.existsByCategoryId(
            CategoryId.fromString('missing-category'),
          )).valueOrNull,
          isFalse,
        );

        expect(
          (await repository.existsByJarId(
            JarId.fromString('missing-jar'),
          )).valueOrNull,
          isFalse,
        );
      });
    });

    group('query', () {
      test('uses AND between criteria and OR inside each criterion', () async {
        // Given
        final expense = _transaction(
          id: 'query-expense',
          merchantId: 'merchant-grocery',
          accountId: 'account-eur',
        );

        final income = _transaction(
          id: 'query-income',
          kind: TransactionKind.income,
          state: TransactionState.planned,
          merchantId: 'merchant-employer',
          accountId: 'account-chf',
        );

        final unrelated = _transaction(
          id: 'query-unrelated',
          merchantId: 'merchant-other',
          accountId: 'account-chf',
        );

        await repository.createAll([
          expense,
          income,
          unrelated,
        ]);

        // When
        final result = await repository.query(
          TransactionQuery(
            kinds: {
              TransactionKind.expense,
              TransactionKind.income,
            },
            states: {
              TransactionState.actual,
              TransactionState.planned,
            },
            merchantIds: {
              MerchantId.fromString('merchant-grocery'),
              MerchantId.fromString('merchant-employer'),
            },
            accountIds: {
              AccountId.fromString('account-chf'),
            },
          ),
        );

        // Then
        final transactions = result.valueOrNull!;

        expect(
          transactions.map((transaction) => transaction.id),
          [income.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });

      test('effectiveFrom is inclusive and effectiveUntil exclusive', () async {
        // Given
        final from = DateTime.utc(2026, 1, 10);
        final until = DateTime.utc(2026, 1, 11);

        final before = _transaction(
          id: 'range-before',
          effectiveAt: DateTime.utc(2026, 1, 9, 23, 59),
        );

        final atStart = _transaction(
          id: 'range-start',
          effectiveAt: from,
        );

        final atEnd = _transaction(
          id: 'range-end',
          effectiveAt: until,
        );

        await repository.createAll([
          before,
          atStart,
          atEnd,
        ]);

        // When
        final result = await repository.query(
          TransactionQuery(
            effectiveFrom: from,
            effectiveUntil: until,
          ),
        );

        // Then
        expect(
          result.valueOrNull!.map((transaction) => transaction.id),
          [atStart.id],
        );
      });

      test(
        'date filtering compares instants rather than representations',
        () async {
          // Given
          final transaction = _transaction(
            id: 'query-timezone',
            effectiveAt: DateTime.utc(2026, 1, 10, 12),
          );

          await repository.create(transaction);

          // When
          final result = await repository.query(
            TransactionQuery(
              effectiveFrom: DateTime.parse(
                '2026-01-10T14:00:00+02:00',
              ),
              effectiveUntil: DateTime.parse(
                '2026-01-10T15:00:00+02:00',
              ),
            ),
          );

          // Then
          expect(
            result.valueOrNull!.map((transaction) => transaction.id),
            [transaction.id],
          );
        },
      );

      test('unrestricted query returns all transactions', () async {
        // Given
        final first = _transaction(id: 'query-all-first');
        final second = _transaction(id: 'query-all-second');

        await repository.createAll([first, second]);

        // When
        final result = await repository.query(TransactionQuery());

        // Then
        final transactions = result.valueOrNull!;

        expect(
          transactions.map((transaction) => transaction.id),
          [first.id, second.id],
        );

        expect(
          () => transactions.clear(),
          throwsUnsupportedError,
        );
      });
    });

    group('update', () {
      test('replaces a transaction while preserving entityVersion', () async {
        // Given
        final original = _transaction(
          id: 'update',
          description: 'Original',
          entityVersion: 4,
        );

        final replacement = _transaction(
          id: original.id.value,
          description: 'Updated',
          entityVersion: 4,
          modifiedAt: DateTime.utc(2026, 1, 2),
        );

        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(
          original.id,
        )).valueOrNull!;

        expect(stored.description, 'Updated');
        expect(stored.entityVersion, 4);
      });

      test('rejects entityVersion conflict without mutation', () async {
        // Given
        final original = _transaction(
          id: 'version-conflict',
          description: 'Original',
          entityVersion: 4,
        );

        final conflicting = _transaction(
          id: original.id.value,
          description: 'Conflicting',
          entityVersion: 5,
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
          (await repository.getById(original.id)).valueOrNull?.description,
          'Original',
        );
      });

      test('returns typed failures for deleted and missing updates', () async {
        // Given
        final original = _transaction(id: 'update-original');

        await repository.create(original);

        // When
        final deleted = await repository.update(
          _transaction(
            id: original.id.value,
            deletedAt: deletedAt,
          ),
        );

        final missing = await repository.update(
          _transaction(id: 'update-missing'),
        );

        // Then
        expect(
          deleted.failureOrNull,
          isA<TransactionAlreadyDeletedFailure>(),
        );

        expect(
          missing.failureOrNull,
          isA<TransactionNotFoundFailure>(),
        );
      });

      test('prevents changing an existing offset relationship', () async {
        // Given
        final original = _transaction(
          id: 'update-offset-original',
          amount: Decimal.fromInt(100),
        );

        final offset = _offsetTransaction(
          id: 'update-offset',
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
          offsetKind: TransactionOffsetKind.reimbursement,
        );

        await repository.create(original);
        await repository.createOffset(offset);

        final replacement = _offsetTransaction(
          id: offset.id.value,
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
          offsetKind: TransactionOffsetKind.cashback,
          modifiedAt: DateTime.utc(2026, 1, 3),
        );

        // When
        final result = await repository.update(replacement);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionOffsetValidationFailure>(),
        );

        final stored = (await repository.getById(offset.id)).valueOrNull!;

        expect(
          stored.offset?.kind,
          TransactionOffsetKind.reimbursement,
        );
      });

      test('updates an offset while relationship remains unchanged', () async {
        // Given
        final original = _transaction(
          id: 'update-offset-amount-original',
          amount: Decimal.fromInt(100),
        );

        final offset = _offsetTransaction(
          id: 'update-offset-amount',
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
        );

        await repository.create(original);
        await repository.createOffset(offset);

        final replacement = _offsetTransaction(
          id: offset.id.value,
          originalId: original.id.value,
          amount: Decimal.fromInt(50),
          modifiedAt: DateTime.utc(2026, 1, 3),
        );

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(offset.id)).valueOrNull!;

        expect(
          _primaryAmount(stored),
          Decimal.fromInt(50),
        );
      });

      test(
        'rejects reducing original below already consumed offset amount',
        () async {
          // Given
          final original = _transaction(
            id: 'update-original-capacity',
            amount: Decimal.fromInt(100),
          );

          final offset = _offsetTransaction(
            id: 'update-original-capacity-offset',
            originalId: original.id.value,
            amount: Decimal.fromInt(60),
          );

          await repository.create(original);
          await repository.createOffset(offset);

          final replacement = _transaction(
            id: original.id.value,
            amount: Decimal.fromInt(50),
            description: 'Reduced',
            modifiedAt: DateTime.utc(2026, 1, 3),
          );

          // When
          final result = await repository.update(replacement);

          // Then
          expect(
            result.failureOrNull,
            isA<TransactionOffsetExceedsAvailableAmountFailure>(),
          );

          final stored = (await repository.getById(
            original.id,
          )).valueOrNull!;

          expect(
            _primaryAmount(stored),
            Decimal.fromInt(100),
          );
        },
      );

      test('allows original update while existing offsets remain valid', () async {
        // Given
        final original = _transaction(
          id: 'update-original-valid',
          amount: Decimal.fromInt(100),
          description: 'Original',
        );

        final offset = _offsetTransaction(
          id: 'update-original-valid-offset',
          originalId: original.id.value,
          amount: Decimal.fromInt(60),
        );

        await repository.create(original);
        await repository.createOffset(offset);

        final replacement = _transaction(
          id: original.id.value,
          amount: Decimal.fromInt(100),
          description: 'Updated description',
          modifiedAt: DateTime.utc(2026, 1, 3),
        );

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        expect(
          (await repository.getById(
            original.id,
          )).valueOrNull?.description,
          'Updated description',
        );
      });
    });

    group('delete and restore', () {
      test('physically removes and restores a deleted snapshot', () async {
        // Given
        final transaction = _transaction(
          id: 'delete-restore',
          entityVersion: 9,
        );

        await repository.create(transaction);

        // When
        final deleteResult = await repository.delete(transaction.id);

        // Then
        expect(deleteResult.isSuccess, isTrue);

        expect(
          (await repository.getById(transaction.id)).valueOrNull,
          isNull,
        );

        final deletedSnapshot = _transaction(
          id: transaction.id.value,
          deletedAt: deletedAt,
          entityVersion: transaction.entityVersion,
        );

        // When
        final restoreResult = await repository.restore(deletedSnapshot);

        // Then
        expect(restoreResult.isSuccess, isTrue);

        final restored = (await repository.getById(
          transaction.id,
        )).valueOrNull!;

        expect(restored.deletedAt, isNull);
        expect(restored.entityVersion, 9);
      });

      test('returns TransactionNotFoundFailure for missing deletion', () async {
        // When
        final result = await repository.delete(
          TransactionId.fromString('delete-missing'),
        );

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionNotFoundFailure>(),
        );
      });

      test('rejects active and duplicate restore requests', () async {
        // Given
        final active = _transaction(id: 'restore-active');

        await repository.create(active);

        final deletedDuplicate = _transaction(
          id: active.id.value,
          deletedAt: deletedAt,
        );

        // When
        final activeResult = await repository.restore(active);

        final duplicateResult = await repository.restore(
          deletedDuplicate,
        );

        // Then
        expect(
          activeResult.failureOrNull,
          isA<TransactionNotDeletedFailure>(),
        );

        expect(
          duplicateResult.failureOrNull,
          isA<TransactionAlreadyExistsFailure>(),
        );
      });

      test('prevents deleting original while offsets reference it', () async {
        // Given
        final original = _transaction(
          id: 'delete-original-with-offset',
          amount: Decimal.fromInt(100),
        );

        final offset = _offsetTransaction(
          id: 'delete-original-offset',
          originalId: original.id.value,
          amount: Decimal.fromInt(50),
        );

        await repository.create(original);
        await repository.createOffset(offset);

        // When
        final result = await repository.delete(original.id);

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionOffsetValidationFailure>(),
        );

        expect(
          (await repository.getById(original.id)).valueOrNull,
          isNotNull,
        );

        expect(
          (await repository.getById(offset.id)).valueOrNull,
          isNotNull,
        );
      });

      test('permits deleting an offset transaction', () async {
        // Given
        final original = _transaction(
          id: 'delete-offset-original',
          amount: Decimal.fromInt(100),
        );

        final offset = _offsetTransaction(
          id: 'delete-offset',
          originalId: original.id.value,
          amount: Decimal.fromInt(50),
        );

        await repository.create(original);
        await repository.createOffset(offset);

        // When
        final result = await repository.delete(offset.id);

        // Then
        expect(result.isSuccess, isTrue);

        expect(
          (await repository.getById(offset.id)).valueOrNull,
          isNull,
        );

        expect(
          (await repository.getOffsetsForTransaction(
            original.id,
          )).valueOrNull,
          isEmpty,
        );
      });

      test('restores an offset when remaining capacity is sufficient', () async {
        // Given
        final original = _transaction(
          id: 'restore-offset-original',
          amount: Decimal.fromInt(100),
        );

        final offset = _offsetTransaction(
          id: 'restore-offset',
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
        );

        await repository.create(original);
        await repository.createOffset(offset);
        await repository.delete(offset.id);

        final deletedOffset = _offsetTransaction(
          id: offset.id.value,
          originalId: original.id.value,
          amount: Decimal.fromInt(40),
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.restore(deletedOffset);

        // Then
        expect(result.isSuccess, isTrue);

        final restored = (await repository.getById(
          offset.id,
        )).valueOrNull!;

        expect(restored.deletedAt, isNull);
        expect(restored.isOffset, isTrue);
      });

      test(
        'rejects restoring an offset when remaining capacity was consumed',
        () async {
          // Given
          final original = _transaction(
            id: 'restore-over-original',
            amount: Decimal.fromInt(100),
          );

          final first = _offsetTransaction(
            id: 'restore-over-first',
            originalId: original.id.value,
            amount: Decimal.fromInt(60),
          );

          final toDelete = _offsetTransaction(
            id: 'restore-over-deleted',
            originalId: original.id.value,
            amount: Decimal.fromInt(30),
          );

          await repository.create(original);
          await repository.createOffset(first);
          await repository.createOffset(toDelete);
          await repository.delete(toDelete.id);

          final replacement = _offsetTransaction(
            id: 'restore-over-replacement',
            originalId: original.id.value,
            amount: Decimal.fromInt(40),
          );

          await repository.createOffset(replacement);

          final deletedSnapshot = _offsetTransaction(
            id: toDelete.id.value,
            originalId: original.id.value,
            amount: Decimal.fromInt(30),
            deletedAt: deletedAt,
          );

          // When
          final result = await repository.restore(deletedSnapshot);

          // Then
          expect(
            result.failureOrNull,
            isA<TransactionOffsetExceedsAvailableAmountFailure>(),
          );

          expect(
            (await repository.getById(
              toDelete.id,
            )).valueOrNull,
            isNull,
          );
        },
      );
    });

    test(
      'translates malformed persisted transaction to typed failure',
      () async {
        // Given
        const id = 'corrupt-transaction';

        await SembastStores.transactions.record(id).put(
          database,
          <String, Object?>{},
        );

        // When
        final result = await repository.getById(
          TransactionId.fromString(id),
        );

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionPersistenceFailure>(),
        );
      },
    );
  });
}

Transaction _transaction({
  required String id,
  String? description = 'Transaction',
  String? note,
  TransactionKind kind = TransactionKind.expense,
  String merchantId = 'self',
  TransactionState state = TransactionState.actual,
  String accountId = 'account-eur',
  DateTime? effectiveAt,
  DateTime? deletedAt,
  int entityVersion = 1,
  DateTime? modifiedAt,
  Decimal? amount,
  AssetId? assetId,
  TransactionOffset? offset,
  List<TransactionSplit> splits = const [],
  List<LedgerEntry>? ledgerEntries,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  final resolvedAssetId =
      assetId ?? AssetId.fromString('asset-eur');

  final resolvedAmount = amount ?? Decimal.zero;

  final direction = kind == TransactionKind.income
      ? AssetAmountDirection.incoming
      : AssetAmountDirection.outgoing;

  final assetAmount = AssetAmount(
    assetId: resolvedAssetId,
    amount: resolvedAmount,
    direction: direction,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: kind,
    merchantId: merchantId == 'self'
        ? MerchantId.self
        : MerchantId.fromString(merchantId),
    effectiveAt: effectiveAt ?? createdAt,
    description: description,
    note: note,
    state: state,
    offset: offset,
    deletedAt: deletedAt,
    splits: splits,
    ledgerEntries:
        ledgerEntries ??
        [
          LedgerEntry(
            accountId: AccountId.fromString(accountId),
            transactionAmount: assetAmount,
            accountAmount: assetAmount,
            valuationAmount: assetAmount,
            role: LedgerEntryRole.primary,
          ),
        ],
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}

Transaction _offsetTransaction({
  required String id,
  required String originalId,
  required Decimal amount,
  TransactionOffsetKind offsetKind =
      TransactionOffsetKind.reimbursement,
  String merchantId = 'offset-merchant',
  String accountId = 'account-eur',
  String? categoryId,
  String? jarId,
  DateTime? effectiveAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
}) {
  final assetAmount = AssetAmount.incoming(
    assetId: AssetId.fromString('asset-eur'),
    amount: amount,
  );

  final splits = categoryId == null && jarId == null
      ? const <TransactionSplit>[]
      : <TransactionSplit>[
          TransactionSplit(
            transactionAmount: assetAmount,
            valuationAmount: assetAmount,
            categoryId: categoryId == null
                ? null
                : CategoryId.fromString(categoryId),
            jarId: jarId == null
                ? null
                : JarId.fromString(jarId),
          ),
        ];

  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.income,
    merchantId: MerchantId.fromString(merchantId),
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 2),
    description: 'Offset transaction',
    note: null,
    state: TransactionState.actual,
    offset: TransactionOffset(
      originalTransactionId: TransactionId.fromString(originalId),
      kind: offsetKind,
    ),
    deletedAt: deletedAt,
    splits: splits,
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString(accountId),
        transactionAmount: assetAmount,
        accountAmount: assetAmount,
        valuationAmount: assetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: modifiedAt ?? DateTime.utc(2026, 1, 1),
    entityVersion: 1,
  );
}

TransactionSplit _split({
  String? categoryId,
  String? jarId,
  Decimal? amount,
  AssetAmountDirection direction = AssetAmountDirection.outgoing,
}) {
  final assetAmount = AssetAmount(
    assetId: AssetId.fromString('asset-eur'),
    amount: amount ?? Decimal.zero,
    direction: direction,
  );

  return TransactionSplit(
    transactionAmount: assetAmount,
    valuationAmount: assetAmount,
    categoryId: categoryId == null
        ? null
        : CategoryId.fromString(categoryId),
    jarId: jarId == null
        ? null
        : JarId.fromString(jarId),
  );
}

LedgerEntry _ledgerEntry(
  String accountId, {
  LedgerEntryRole role = LedgerEntryRole.primary,
}) {
  final amount = AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-eur'),
    amount: Decimal.zero,
  );

  return LedgerEntry(
    accountId: AccountId.fromString(accountId),
    transactionAmount: amount,
    accountAmount: amount,
    valuationAmount: amount,
    role: role,
  );
}

Decimal _primaryAmount(Transaction transaction) {
  return transaction.ledgerEntries
      .singleWhere(
        (entry) => entry.role == LedgerEntryRole.primary,
      )
      .transactionAmount
      .amount;
}