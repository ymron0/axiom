@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('TransactionPersistenceModel', () {
    test('round-trips an allocated transaction and its persistence order', () {
      // Given
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('category-1'),
      );

      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      );

      // When
      final record = model.toRecord();

      final restored = TransactionPersistenceModel.fromRecord(
        transaction.id.value,
        record,
      ).toEntity();

      // Then
      expect(TransactionPersistenceModel.readPersistenceOrder(record), 1);

      expect(restored, transaction);
      expect(restored.offset, isNull);
    });

    test('round-trips a transaction offset relationship', () {
      // Given
      final transaction = _offsetTransaction();

      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 7,
      );

      // When
      final record = model.toRecord();

      final restored = TransactionPersistenceModel.fromRecord(
        transaction.id.value,
        record,
      ).toEntity();

      // Then
      expect(record['offsetOfTransactionId'], 'original-transaction');
      expect(record['offsetKind'], 'reimbursement');

      expect(restored.id, transaction.id);
      expect(restored.isOffset, isTrue);

      expect(
        restored.offset?.originalTransactionId,
        TransactionId.fromString('original-transaction'),
      );

      expect(restored.offset?.kind, TransactionOffsetKind.reimbursement);

      expect(TransactionPersistenceModel.readPersistenceOrder(record), 7);
    });

    test('treats records without offset fields as standalone transactions', () {
      // Given
      final transaction = transactionFixture(id: 'legacy-transaction');

      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      );

      final record = <String, Object?>{...model.toRecord()}
        ..remove('offsetOfTransactionId')
        ..remove('offsetKind');

      // When
      final restored = TransactionPersistenceModel.fromRecord(
        transaction.id.value,
        record,
      ).toEntity();

      // Then
      expect(restored.id, transaction.id);
      expect(restored.offset, isNull);
      expect(restored.isOffset, isFalse);
    });

    test('rejects persisted offset identifier without offset kind', () {
      // Given
      final transaction = transactionFixture(id: 'half-offset-id');

      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        'offsetOfTransactionId': 'original',
      }..remove('offsetKind');

      // When / Then
      expect(
        () => TransactionPersistenceModel.fromRecord(
          transaction.id.value,
          record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects persisted offset kind without offset identifier', () {
      // Given
      final transaction = transactionFixture(id: 'half-offset-kind');

      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        'offsetKind': TransactionOffsetKind.refund.name,
      }..remove('offsetOfTransactionId');

      // When / Then
      expect(
        () => TransactionPersistenceModel.fromRecord(
          transaction.id.value,
          record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects unsupported persisted offset kind', () {
      // Given
      final transaction = transactionFixture(id: 'invalid-offset-kind');

      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      );

      final record = <String, Object?>{
        ...model.toRecord(),
        'offsetOfTransactionId': 'original',
        'offsetKind': 'unsupported',
      };

      // When / Then
      expect(
        () => TransactionPersistenceModel.fromRecord(
          transaction.id.value,
          record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects invalid persistence order and malformed nested records', () {
      // Given
      final transaction = transactionFixture(id: 'transaction-1');

      // Then
      expect(
        () => TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: 0,
        ),
        throwsArgumentError,
      );

      final record = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      ).toRecord();

      expect(
        () => TransactionPersistenceModel.readPersistenceOrder(
          <String, Object?>{...record, 'persistenceOrder': 0},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );

      expect(
        () => TransactionPersistenceModel.fromRecord(
          'transaction-1',
          <String, Object?>{
            ...record,
            'ledgerEntries': <Object?>['invalid'],
          },
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects deleted transactions before persistence', () {
      // Given
      final transaction = transactionFixture(
        id: 'deleted-transaction',
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      // When / Then
      expect(
        () => TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: 1,
        ),
        throwsArgumentError,
      );
    });

    test(
      'translates invalid persisted identity during entity reconstruction',
      () {
        // Given
        final transaction = transactionFixture(id: 'transaction-1');

        final record = TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: 1,
        ).toRecord();

        final model = TransactionPersistenceModel.fromRecord('', record);

        // When / Then
        expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
      },
    );

    test(
      'translates invalid persisted offset identity during reconstruction',
      () {
        // Given
        final transaction = transactionFixture(id: 'invalid-offset-id');

        final record = <String, Object?>{
          ...TransactionPersistenceModel.fromEntity(
            transaction,
            persistenceOrder: 1,
          ).toRecord(),
          'offsetOfTransactionId': '',
          'offsetKind': TransactionOffsetKind.refund.name,
        };

        final model = TransactionPersistenceModel.fromRecord(
          transaction.id.value,
          record,
        );

        // When / Then
        expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
      },
    );
  });
}

Transaction _offsetTransaction() {
  final amount = AssetAmount.incoming(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.fromInt(50),
  );

  final timestamp = DateTime.utc(2026, 1, 2);

  return Transaction(
    id: TransactionId.fromString('offset-transaction'),
    kind: TransactionKind.income,
    merchantId: MerchantId.fromString('partner'),
    effectiveAt: timestamp,
    description: 'Partner reimbursement',
    note: null,
    state: TransactionState.actual,
    offset: TransactionOffset(
      originalTransactionId: TransactionId.fromString('original-transaction'),
      kind: TransactionOffsetKind.reimbursement,
    ),
    deletedAt: null,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-chf'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
