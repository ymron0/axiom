@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/refund_fixtures.dart';

void main() {
  group('Transaction', () {
    test(
      'creates a new transaction with generated identity and audit metadata',
      () {
        // Given
        final effectiveAt = DateTime.parse('2024-01-02T03:04:05+01:00');
        final createdAt = DateTime.utc(2026, 9, 12, 10, 11, 12);

        // When
        final transaction = Transaction.create(
          kind: TransactionKind.expense,
          merchantId: MerchantId.self,
          effectiveAt: effectiveAt,
          description: '  groceries  ',
          note: '  weekly shop  ',
          state: TransactionState.actual,
          splits: const [],
          ledgerEntries: [_createLedgerEntry()],
          clock: FixedClock(createdAt),
        );

        // Then
        expect(transaction.id, isA<TransactionId>());
        expect(transaction.id.value, isNotEmpty);
        expect(transaction.kind, TransactionKind.expense);
        expect(transaction.merchantId, same(MerchantId.self));
        expect(transaction.effectiveAt, effectiveAt.toUtc());
        expect(transaction.description, 'groceries');
        expect(transaction.note, 'weekly shop');
        expect(transaction.state, TransactionState.actual);

        expect(transaction.tagIds, isEmpty);
        expect(transaction.splits, isEmpty);
        expect(transaction.ledgerEntries, hasLength(1));
        expect(transaction.createdAt, createdAt);
        expect(transaction.modifiedAt, createdAt);
        expect(transaction.entityVersion, 1);
        expect(transaction.deletedAt, isNull);
      },
    );

    test(
      'creates a transaction with the default clock when none is supplied',
      () {
        // When
        final transaction = Transaction.create(
          kind: TransactionKind.expense,
          merchantId: MerchantId.self,
          effectiveAt: DateTime.utc(2024),
          state: TransactionState.actual,
          splits: const [],
          ledgerEntries: [_createLedgerEntry()],
        );

        // Then
        expect(transaction.createdAt.isUtc, isTrue);
        expect(transaction.modifiedAt, transaction.createdAt);
      },
    );

    test('constructs a valid immutable aggregate', () {
      // Given / When
      final transaction = _createTransaction();

      // Then
      expect(transaction.id.value, 'transaction-1');
      expect(transaction.kind, TransactionKind.expense);
      expect(transaction.state, TransactionState.actual);
      expect(transaction.ledgerEntries, hasLength(1));
      expect(transaction.splits, isEmpty);
      expect(transaction.entityVersion, 1);
      expect(transaction.deletedAt, isNull);
      expect(transaction.isDeleted, isFalse);
    });

    test(
      'preserves a deletion timestamp and reports the aggregate deleted',
      () {
        // Given
        final deletedAt = DateTime.utc(2024, 1, 2);

        // When
        final transaction = _createTransaction(deletedAt: deletedAt);

        // Then
        expect(transaction.deletedAt, same(deletedAt));
        expect(transaction.isDeleted, isTrue);
      },
    );

    test('rejects a deletion timestamp before creation', () {
      // Given
      final deletedAt = DateTime.utc(2023, 12, 31, 23, 59, 59);

      // When
      Transaction construct() => _createTransaction(deletedAt: deletedAt);

      // Then
      expect(
        construct,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.invalidValue, 'invalidValue', deletedAt)
              .having((error) => error.name, 'name', 'deletedAt'),
        ),
      );
    });

    test('preserves the designated self merchant identity', () {
      // Given / When
      final transaction = _createTransaction();

      // Then
      expect(transaction.merchantId, same(MerchantId.self));
    });

    test('normalizes optional text through the shared validator', () {
      // Given / When
      final transaction = _createTransaction(
        description: '  groceries  ',
        note: '  weekly shop  ',
      );

      // Then
      expect(transaction.description, 'groceries');
      expect(transaction.note, 'weekly shop');
    });

    test('preserves omitted optional text as null', () {
      // Given / When
      final transaction = _createTransaction();

      // Then
      expect(transaction.description, isNull);
      expect(transaction.note, isNull);
    });

    test('rejects blank optional text', () {
      // Given / When / Then
      expect(
        () => _createTransaction(description: '  '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'description',
          ),
        ),
      );
    });

    test('rejects an expense without exactly one outgoing primary entry', () {
      // Given / When / Then
      expect(
        () => _createTransaction(ledgerEntries: const []),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => _createTransaction(
          ledgerEntries: [_createLedgerEntry(incoming: true)],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an expense with multiple primary entries', () {
      // Given / When / Then
      final entry = _createLedgerEntry();

      expect(
        () => _createTransaction(ledgerEntries: [entry, entry]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a balance correction without exactly one primary entry', () {
      // Given / When / Then
      expect(
        () => _createTransaction(
          kind: TransactionKind.balanceCorrection,
          ledgerEntries: [_createLedgerEntry(), _createLedgerEntry()],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a transfer without opposing primary entries', () {
      // Given / When / Then
      expect(
        () => _createTransaction(
          kind: TransactionKind.transfer,
          ledgerEntries: [_createLedgerEntry(), _createLedgerEntry()],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts a split collection that reconciles exactly', () {
      // Given / When
      final transaction = _createTransaction(
        splits: [
          TransactionSplit(
            transactionAmount: _createAmount(),
            valuationAmount: _createAmount(),
            categoryId: CategoryId.fromString('category-1'),
          ),
        ],
      );

      // Then
      expect(transaction.splits, hasLength(1));
    });

    test('rejects splits when a primary ledger amount is unknown', () {
      // Given
      final unknownAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-eur'),
        amount: Decimal.fromInt(-1),
      );

      // When / Then
      expect(
        () => _createTransaction(
          ledgerEntries: [_createLedgerEntry(amount: unknownAmount)],
          splits: [
            _createSplit(
              transactionAmount: unknownAmount,
              valuationAmount: unknownAmount,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects splits whose valuation total does not reconcile', () {
      // Given
      final transactionAmount = _createAmount();
      final valuationAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.fromInt(10),
      );

      // When / Then
      expect(
        () => _createTransaction(
          ledgerEntries: [
            _createLedgerEntry(
              transactionAmount: transactionAmount,
              valuationAmount: valuationAmount,
            ),
          ],
          splits: [
            _createSplit(
              transactionAmount: transactionAmount,
              valuationAmount: AssetAmount.outgoing(
                assetId: AssetId.fromString('asset-chf'),
                amount: Decimal.fromInt(9),
              ),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a split with an unknown transaction amount', () {
      // Given
      final unknownAmount = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-eur'),
        amount: Decimal.fromInt(-1),
      );

      // When / Then
      expect(
        () => _createTransaction(
          splits: [
            _createSplit(
              transactionAmount: unknownAmount,
              valuationAmount: unknownAmount,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a split with a different transaction asset', () {
      // Given / When / Then
      expect(
        () => _createTransaction(
          splits: [
            _createSplit(
              transactionAmount: AssetAmount.outgoing(
                assetId: AssetId.fromString('asset-usd'),
                amount: Decimal.fromInt(10),
              ),
              valuationAmount: _createAmount(),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a split with a different transaction direction', () {
      // Given / When / Then
      expect(
        () => _createTransaction(
          splits: [
            _createSplit(
              transactionAmount: AssetAmount.incoming(
                assetId: AssetId.fromString('asset-eur'),
                amount: Decimal.fromInt(10),
              ),
              valuationAmount: AssetAmount.incoming(
                assetId: AssetId.fromString('asset-eur'),
                amount: Decimal.fromInt(10),
              ),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unsupported splits', () {
      // Given / When / Then
      expect(
        () => _createTransaction(
          kind: TransactionKind.transfer,
          ledgerEntries: [
            _createLedgerEntry(),
            _createLedgerEntry(incoming: true),
          ],
          splits: [
            TransactionSplit(
              transactionAmount: _createAmount(),
              valuationAmount: _createAmount(),
              categoryId: CategoryId.fromString('category-1'),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects split totals that do not reconcile', () {
      // Given / When / Then
      expect(
        () => _createTransaction(
          splits: [
            TransactionSplit(
              transactionAmount: AssetAmount.outgoing(
                assetId: AssetId.fromString('asset-eur'),
                amount: Decimal.fromInt(9),
              ),
              valuationAmount: AssetAmount.outgoing(
                assetId: AssetId.fromString('asset-eur'),
                amount: Decimal.fromInt(9),
              ),
              categoryId: CategoryId.fromString('category-1'),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('defensively copies supplied collections', () {
      // Given
      final entries = [_createLedgerEntry()];
      final splits = <TransactionSplit>[];

      // When
      final transaction = _createTransaction(
        ledgerEntries: entries,
        splits: splits,
      );
      entries.clear();
      splits.clear();

      // Then
      expect(transaction.ledgerEntries, hasLength(1));
      expect(transaction.splits, isEmpty);
      expect(
        () => transaction.ledgerEntries.add(_createLedgerEntry()),
        throwsUnsupportedError,
      );
    });

    test('compares equivalent aggregates by mapped values', () {
      // Given
      final first = _createTransaction(description: 'groceries');
      final equivalent = _createTransaction(description: 'groceries');
      final different = _createTransaction(description: 'rent');
      final deleted = _createTransaction(
        description: 'groceries',
        deletedAt: DateTime.utc(2024, 1, 2),
      );

      // Then
      expect(first, equals(equivalent));
      expect(first, isNot(equals(different)));
      expect(first, isNot(equals(deleted)));
    });
    test(
      'identifies a transaction with an offset relationship as an offset',
      () {
        // Given
        final transaction = refundTransactionFixture();

        // Then
        expect(transaction.isOffset, isTrue);
        expect(
          transaction.offset?.originalTransactionId,
          TransactionId.fromString('refund-original'),
        );
      },
    );

    test('rejects a self-referencing offset relationship', () {
      // Given
      final original = refundableExpenseTransactionFixture(
        id: 'self-referencing',
      );
      final offset = refundTransactionFixture(
        id: 'self-referencing',
        originalTransactionId: 'self-referencing',
      );

      // When
      final result = const TransactionOffsetPolicy().validateNewOffset(
        original: original,
        offset: offset,
        existingOffsets: const [],
      );

      // Then
      expect(result.failureOrNull, isA<TransactionOffsetValidationFailure>());
    });

    test(
      'identifies a transaction without an offset relationship as standalone',
      () {
        // Given
        final transaction = _createTransaction();

        // Then
        expect(transaction.offset, isNull);
        expect(transaction.isOffset, isFalse);
      },
    );

    test('stores immutable transaction-level tag identities', () {
      // Given
      final tagIds = [
        TagId.fromString('tag-business'),
        TagId.fromString('tag-tax'),
      ];

      // When
      final transaction = _createTransaction(tagIds: tagIds);
      tagIds.clear();

      // Then
      expect(transaction.tagIds, [
        TagId.fromString('tag-business'),
        TagId.fromString('tag-tax'),
      ]);
      expect(
        () => transaction.tagIds.add(TagId.fromString('tag-other')),
        throwsUnsupportedError,
      );
    });

    test('allows a transaction without tags', () {
      // Given / When
      final transaction = _createTransaction();

      // Then
      expect(transaction.tagIds, isEmpty);
    });

    test('rejects duplicate tag identities', () {
      // Given
      final tagId = TagId.fromString('tag-business');

      // When / Then
      expect(
        () => _createTransaction(tagIds: [tagId, tagId]),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'tagIds'),
        ),
      );
    });

    test('treats tags as transaction metadata independent of splits', () {
      // Given
      final tagId = TagId.fromString('tag-business');

      // When
      final transaction = _createTransaction(
        tagIds: [tagId],
        splits: [
          TransactionSplit(
            transactionAmount: _createAmount(),
            valuationAmount: _createAmount(),
            categoryId: CategoryId.fromString('category-1'),
          ),
        ],
      );

      // Then
      expect(transaction.tagIds, [tagId]);
      expect(
        transaction.splits.single.categoryId,
        CategoryId.fromString('category-1'),
      );
    });
  });
}

Transaction _createTransaction({
  String? description,
  String? note,
  DateTime? deletedAt,
  TransactionKind kind = TransactionKind.expense,
  List<TagId> tagIds = const [],
  List<TransactionSplit> splits = const [],
  List<LedgerEntry>? ledgerEntries,
}) {
  return Transaction(
    id: TransactionId.fromString('transaction-1'),
    kind: kind,
    merchantId: MerchantId.self,
    effectiveAt: DateTime.utc(2024),
    description: description,
    note: note,
    state: TransactionState.actual,
    deletedAt: deletedAt,
    tagIds: tagIds,
    splits: splits,
    ledgerEntries: ledgerEntries ?? [_createLedgerEntry()],
    createdAt: DateTime.utc(2024),
    modifiedAt: DateTime.utc(2024),
    entityVersion: 1,
  );
}

LedgerEntry _createLedgerEntry({
  bool incoming = false,
  AssetAmount? amount,
  AssetAmount? transactionAmount,
  AssetAmount? valuationAmount,
  LedgerEntryRole role = LedgerEntryRole.primary,
}) {
  final defaultAmount = incoming
      ? AssetAmount.incoming(
          assetId: AssetId.fromString('asset-eur'),
          amount: Decimal.fromInt(10),
        )
      : _createAmount();
  final resolvedTransactionAmount =
      transactionAmount ?? amount ?? defaultAmount;

  return LedgerEntry(
    accountId: AccountId.fromString('account-1'),
    transactionAmount: resolvedTransactionAmount,
    accountAmount: resolvedTransactionAmount,
    valuationAmount: valuationAmount ?? resolvedTransactionAmount,
    role: role,
  );
}

TransactionSplit _createSplit({
  required AssetAmount transactionAmount,
  required AssetAmount valuationAmount,
}) {
  return TransactionSplit(
    transactionAmount: transactionAmount,
    valuationAmount: valuationAmount,
    categoryId: CategoryId.fromString('category-1'),
  );
}

AssetAmount _createAmount() {
  return AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-eur'),
    amount: Decimal.fromInt(10),
  );
}
