@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/tags/data/models/tag_persistence_model.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';
import 'package:test/test.dart';

void main() {
  group('TagPersistenceModel', () {
    test('round-trips active tag', () {
      final tag = _tag(id: 'business', name: 'Business');

      final model = TagPersistenceModel.fromEntity(tag);
      final record = model.toRecord();

      final restored = TagPersistenceModel.fromRecord(
        recordKey: tag.id.value,
        record: record,
      ).toEntity();

      expect(restored, tag);
    });

    test('persists canonical normalized name key', () {
      final tag = _tag(id: 'business', name: 'Business Trip');

      final model = TagPersistenceModel.fromEntity(tag);
      final record = model.toRecord();

      expect(model.nameKey, 'business trip');

      expect(record[TagPersistenceModel.nameKeyField], 'business trip');
    });

    test('accepts legacy record without nameKey', () {
      final tag = _tag(id: 'legacy', name: 'Business Trip');

      final record = TagPersistenceModel.fromEntity(tag).toRecord()
        ..remove(TagPersistenceModel.nameKeyField);

      final model = TagPersistenceModel.fromRecord(
        recordKey: tag.id.value,
        record: record,
      );

      expect(model.nameKey, tagNameKey(tag.name));
      expect(model.toEntity(), tag);
    });

    test('rejects persisted nameKey inconsistent with name', () {
      final tag = _tag(id: 'corrupt', name: 'Business');

      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      record[TagPersistenceModel.nameKeyField] = 'personal';

      expect(
        () => TagPersistenceModel.fromRecord(
          recordKey: tag.id.value,
          record: record,
        ),
        throwsA(
          isA<PersistenceRecordException>().having(
            (error) => error.field,
            'field',
            TagPersistenceModel.nameKeyField,
          ),
        ),
      );
    });

    test('rejects invalid persisted name before index derivation', () {
      final tag = _tag(id: 'blank');

      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      record[TagPersistenceModel.nameField] = '   ';
      record.remove(TagPersistenceModel.nameKeyField);

      expect(
        () => TagPersistenceModel.fromRecord(
          recordKey: tag.id.value,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('round-trips lifecycle metadata', () {
      final archivedAt = DateTime.utc(2026, 1, 2);
      final deletedAt = DateTime.utc(2026, 1, 3);

      final tag = _tag(
        id: 'lifecycle',
        archivedAt: archivedAt,
        deletedAt: deletedAt,
        modifiedAt: archivedAt,
      );

      final restored = TagPersistenceModel.fromRecord(
        recordKey: tag.id.value,
        record: TagPersistenceModel.fromEntity(tag).toRecord(),
      ).toEntity();

      expect(restored.archivedAt, archivedAt);
      expect(restored.deletedAt, deletedAt);
    });

    test('writes timestamps in UTC', () {
      final tag = Tag(
        id: TagId.fromString('time'),
        name: 'Time',
        createdAt: DateTime.parse('2026-01-01T10:00:00+01:00'),
        modifiedAt: DateTime.parse('2026-01-01T11:00:00+01:00'),
        entityVersion: 1,
      );

      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      expect(record['createdAt'], '2026-01-01T09:00:00.000Z');
      expect(record['modifiedAt'], '2026-01-01T10:00:00.000Z');
    });

    test('rejects malformed timestamp', () {
      final tag = _tag(id: 'invalid-date');

      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      record['createdAt'] = 'not-a-date';

      expect(
        () => TagPersistenceModel.fromRecord(
          recordKey: tag.id.value,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects non-positive entity version', () {
      final tag = _tag(id: 'invalid-version');

      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      record['entityVersion'] = 0;

      expect(
        () => TagPersistenceModel.fromRecord(
          recordKey: tag.id.value,
          record: record,
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('translates invalid persisted identity during toEntity', () {
      final tag = _tag(id: 'valid');

      final model = TagPersistenceModel.fromRecord(
        recordKey: '',
        record: TagPersistenceModel.fromEntity(tag).toRecord(),
      );

      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('normalizes persisted display name during reconstruction', () {
      final tag = _tag(id: 'normalize');

      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      record[TagPersistenceModel.nameField] = '  Business   Trip ';
      record.remove(TagPersistenceModel.nameKeyField);

      final restored = TagPersistenceModel.fromRecord(
        recordKey: tag.id.value,
        record: record,
      ).toEntity();

      expect(restored.name, 'Business Trip');
    });
  });
}

Tag _tag({
  required String id,
  String name = 'Business',
  DateTime? createdAt,
  DateTime? modifiedAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);

  return Tag(
    id: TagId.fromString(id),
    name: name,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    entityVersion: 1,
  );
}
