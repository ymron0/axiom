@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_split_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('TransactionSplitPersistenceModel', () {
    test('round-trips a category allocation', () {
      final split = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('category-1'),
      ).splits.single;
      final model = TransactionSplitPersistenceModel.fromEntity(split);

      expect(
        TransactionSplitPersistenceModel.fromRecord(
          model.toRecord(),
          path: 'splits[0]',
        ).toEntity(),
        split,
      );
    });

    test('rejects malformed records and allocation-free splits', () {
      final record = TransactionSplitPersistenceModel.fromEntity(
        transactionWithCategoryAllocationFixture(
          categoryId: CategoryId.fromString('category-1'),
        ).splits.single,
      ).toRecord();
      expect(
        () => TransactionSplitPersistenceModel.fromRecord(<String, Object?>{
          ...record,
          'valuationAmount': 10,
        }, path: 'splits[0]'),
        throwsA(isA<PersistenceRecordException>()),
      );
      final invalid = TransactionSplitPersistenceModel.fromRecord(
        <String, Object?>{...record, 'categoryId': null, 'jarId': null},
        path: 'splits[0]',
      );
      expect(invalid.toEntity, throwsArgumentError);
    });
  });
}
