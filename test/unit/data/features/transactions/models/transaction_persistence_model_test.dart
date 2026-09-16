@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('TransactionPersistenceModel', () {
    test('round-trips an allocated transaction and its persistence order', () {
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('category-1'),
      );
      final model = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      );
      final record = model.toRecord();

      expect(TransactionPersistenceModel.readPersistenceOrder(record), 1);
      expect(
        TransactionPersistenceModel.fromRecord(transaction.id.value, record).toEntity(),
        transaction,
      );
    });

    test('rejects invalid persistence order and malformed nested records', () {
      final transaction = transactionFixture(id: 'transaction-1');
      expect(
        () => TransactionPersistenceModel.fromEntity(transaction, persistenceOrder: 0),
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
          <String, Object?>{...record, 'ledgerEntries': <Object?>['invalid']},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects deleted transactions before persistence', () {
      final transaction = transactionFixture(
        id: 'deleted-transaction',
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      expect(
        () => TransactionPersistenceModel.fromEntity(
          transaction,
          persistenceOrder: 1,
        ),
        throwsArgumentError,
      );
    });

    test('translates invalid persisted identity during entity reconstruction', () {
      final transaction = transactionFixture(id: 'transaction-1');
      final record = TransactionPersistenceModel.fromEntity(
        transaction,
        persistenceOrder: 1,
      ).toRecord();
      final model = TransactionPersistenceModel.fromRecord('', record);

      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });
  });
}
