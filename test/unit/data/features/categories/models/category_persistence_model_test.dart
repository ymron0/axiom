@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/categories/data/models/category_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';

void main() {
  group('CategoryPersistenceModel', () {
    test('round-trips an active category', () {
      final category = categoryFixture(id: 'category-1');
      final model = CategoryPersistenceModel.fromEntity(category);

      expect(
        CategoryPersistenceModel.fromRecord(
          recordKey: category.id.value,
          record: model.toRecord(),
        ).toEntity(),
        category,
      );
    });

    test('rejects deleted categories and malformed persisted values', () {
      expect(
        () => CategoryPersistenceModel.fromEntity(
          categoryFixture(id: 'category-1', deletedAt: DateTime.utc(2026)),
        ),
        throwsStateError,
      );
      final record = CategoryPersistenceModel.fromEntity(
        categoryFixture(id: 'category-1'),
      ).toRecord();
      expect(
        () => CategoryPersistenceModel.fromRecord(
          recordKey: 'category-1',
          record: <String, Object?>{...record, 'budgets': <Object?>[42]},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final deleted = CategoryPersistenceModel.fromRecord(
        recordKey: 'category-1',
        record: <String, Object?>{
          ...record,
          'deletedAt': '2026-01-01T00:00:00.000Z',
        },
      );
      expect(deleted.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('translates invalid persisted IDs and timestamps', () {
      final record = CategoryPersistenceModel.fromEntity(
        categoryFixture(id: 'category-1'),
      ).toRecord();
      final invalidId = CategoryPersistenceModel.fromRecord(
        recordKey: '',
        record: record,
      );
      expect(invalidId.toEntity, throwsA(isA<PersistenceRecordException>()));
      expect(
        () => CategoryPersistenceModel.fromRecord(
          recordKey: 'category-1',
          record: <String, Object?>{...record, 'createdAt': '2026-01-01'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      expect(
        () => CategoryPersistenceModel.fromRecord(
          recordKey: 'category-1',
          record: <String, Object?>{...record, 'archivedAt': 'not-a-timestamp'},
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (exception) => exception.field,
            'field',
            'archivedAt',
          ),
        ),
      );
    });
  });
}
