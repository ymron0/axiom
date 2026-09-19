@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:test/test.dart';

void main() {
  group('Tag', () {
    test('creates a tag with generated identity and audit metadata', () {
      final timestamp = DateTime.parse('2026-09-19T10:30:00+02:00');

      final tag = Tag.create(
        name: '  Business   Trip  ',
        clock: FixedClock(timestamp),
      );

      expect(tag.id.value, isNotEmpty);
      expect(tag.name, 'Business Trip');
      expect(tag.entityVersion, 1);
      expect(tag.createdAt, timestamp.toUtc());
      expect(tag.modifiedAt, same(tag.createdAt));
      expect(tag.archivedAt, isNull);
      expect(tag.deletedAt, isNull);
      expect(tag.isArchived, isFalse);
      expect(tag.isDeleted, isFalse);
    });

    test('uses the default clock when none is supplied', () {
      final tag = Tag.create(name: 'Business');

      expect(tag.createdAt.isUtc, isTrue);
      expect(tag.modifiedAt, tag.createdAt);
    });

    test('rejects a blank name', () {
      expect(
        () => _createTag(name: '  '),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'name'),
        ),
      );
    });

    test('normalizes persisted names', () {
      final tag = _createTag(name: '  Tax   Deductible ');

      expect(tag.name, 'Tax Deductible');
    });

    test('preserves archival state', () {
      final archivedAt = DateTime.utc(2026, 9, 19);

      final tag = _createTag(modifiedAt: archivedAt, archivedAt: archivedAt);

      expect(tag.archivedAt, same(archivedAt));
      expect(tag.isArchived, isTrue);
    });

    test('preserves deletion state', () {
      final deletedAt = DateTime.utc(2026, 9, 20);

      final tag = _createTag(modifiedAt: deletedAt, deletedAt: deletedAt);

      expect(tag.deletedAt, same(deletedAt));
      expect(tag.isDeleted, isTrue);
    });

    test('rejects archive before creation', () {
      final archivedAt = DateTime.utc(2026, 9, 17);

      expect(
        () => _createTag(archivedAt: archivedAt),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'archivedAt')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                archivedAt,
              ),
        ),
      );
    });

    test('rejects archive after modification', () {
      final archivedAt = DateTime.utc(2026, 9, 20);

      expect(
        () => _createTag(archivedAt: archivedAt),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'archivedAt',
          ),
        ),
      );
    });

    test('rejects deletion before creation', () {
      final deletedAt = DateTime.utc(2026, 9, 17);

      expect(
        () => _createTag(deletedAt: deletedAt),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'deletedAt',
          ),
        ),
      );
    });

    test('rejects deletion before archive', () {
      final archivedAt = DateTime.utc(2026, 9, 19);
      final deletedAt = DateTime.utc(2026, 9, 18, 12);

      expect(
        () => _createTag(
          modifiedAt: archivedAt,
          archivedAt: archivedAt,
          deletedAt: deletedAt,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'deletedAt',
          ),
        ),
      );
    });

    test('rejects invalid audit metadata', () {
      expect(
        () => _createTag(entityVersion: 0),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'entityVersion',
          ),
        ),
      );
    });

    test('compares equivalent tags by mapped values', () {
      final first = _createTag();
      final equivalent = _createTag();
      final different = _createTag(id: TagId.fromString('tag-2'));

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });
  });
}

Tag _createTag({
  TagId? id,
  String name = 'Business',
  DateTime? archivedAt,
  DateTime? deletedAt,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 18);

  return Tag(
    id: id ?? TagId.fromString('tag-1'),
    name: name,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    entityVersion: entityVersion,
  );
}
