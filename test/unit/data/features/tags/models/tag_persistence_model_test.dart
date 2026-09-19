@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/tags/data/models/tag_persistence_model.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:test/test.dart';

void main() {
  group('TagPersistenceModel', () {
    test('round-trips an active tag', () {
      // Given
      final tag = _tag(id: 'tag-business', name: 'Business');

      // When
      final model = TagPersistenceModel.fromEntity(tag);
      final record = model.toRecord();

      final restored = TagPersistenceModel.fromRecord(
        recordKey: tag.id.value,
        record: record,
      ).toEntity();

      // Then
      expect(restored, tag);
    });

    test('round-trips archival and deletion metadata', () {
      // Given
      final archivedAt = DateTime.utc(2026, 1, 2);
      final deletedAt = DateTime.utc(2026, 1, 3);

      final tag = _tag(
        id: 'tag-lifecycle',
        archivedAt: archivedAt,
        deletedAt: deletedAt,
        modifiedAt: archivedAt,
      );

      // When
      final restored = TagPersistenceModel.fromRecord(
        recordKey: tag.id.value,
        record: TagPersistenceModel.fromEntity(tag).toRecord(),
      ).toEntity();

      // Then
      expect(restored.archivedAt, archivedAt);
      expect(restored.deletedAt, deletedAt);
    });

    test('canonicalizes persisted timestamps to UTC', () {
      // Given
      final tag = Tag(
        id: TagId.fromString('tag-time'),
        name: 'Time',
        createdAt: DateTime.parse('2026-01-01T10:00:00+01:00'),
        modifiedAt: DateTime.parse('2026-01-01T11:00:00+01:00'),
        entityVersion: 1,
      );

      // When
      final record = TagPersistenceModel.fromEntity(tag).toRecord();

      // Then
      expect(record['createdAt'], '2026-01-01T09:00:00.000Z');
      expect(record['modifiedAt'], '2026-01-01T10:00:00.000Z');
    });

    test('rejects malformed persisted timestamps', () {
      // Given
      final record = TagPersistenceModel.fromEntity(
        _tag(id: 'tag-invalid'),
      ).toRecord();

      // When / Then
      expect(
        () => TagPersistenceModel.fromRecord(
          recordKey: 'tag-invalid',
          record: <String, Object?>{...record, 'createdAt': 'not-a-date'},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('rejects non-positive entity version', () {
      // Given
      final record = TagPersistenceModel.fromEntity(
        _tag(id: 'tag-version'),
      ).toRecord();

      // When / Then
      expect(
        () => TagPersistenceModel.fromRecord(
          recordKey: 'tag-version',
          record: <String, Object?>{...record, 'entityVersion': 0},
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
    });

    test('translates an invalid persisted identity', () {
      // Given
      final model = TagPersistenceModel.fromRecord(
        recordKey: '',
        record: TagPersistenceModel.fromEntity(_tag(id: 'valid')).toRecord(),
      );

      // When / Then
      expect(model.toEntity, throwsA(isA<PersistenceRecordException>()));
    });

    test('re-applies tag name normalization during reconstruction', () {
      // Given
      final record = TagPersistenceModel.fromEntity(
        _tag(id: 'tag-normalized'),
      ).toRecord();

      // When
      final restored = TagPersistenceModel.fromRecord(
        recordKey: 'tag-normalized',
        record: <String, Object?>{...record, 'name': '  Business   Trip  '},
      ).toEntity();

      // Then
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
