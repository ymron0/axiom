import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/domain/value_objects/test_unique_id.dart';

part 'audited_entity_test.mapper.dart';

void main() {
  group('AuditedEntity', () {
    group('construction', () {
      test('preserves identity, version, and ordered timestamps', () {
        // Given
        final id = TestUniqueId('entity-id');
        final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
        final modifiedAt = createdAt.add(const Duration(days: 1));

        // When
        final entity = TestAuditedEntity(
          id: id,
          entityVersion: 3,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        );

        // Then
        expect(entity.id, same(id));
        expect(entity.entityVersion, 3);
        expect(entity.createdAt, createdAt);
        expect(entity.modifiedAt, modifiedAt);
      });

      test('accepts equal creation and modification timestamps', () {
        // Given
        final timestamp = DateTime.utc(2026, 1, 2, 3, 4, 5);

        // When
        final entity = TestAuditedEntity(
          id: TestUniqueId('entity-id'),
          entityVersion: 1,
          createdAt: timestamp,
          modifiedAt: timestamp,
        );

        // Then
        expect(entity.createdAt, entity.modifiedAt);
      });

      test('rejects a modification timestamp before creation', () {
        // Given
        final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
        final modifiedAt = createdAt.subtract(const Duration(microseconds: 1));

        // When
        TestAuditedEntity construct() => TestAuditedEntity(
          id: TestUniqueId('entity-id'),
          entityVersion: 1,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        );

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>()
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  modifiedAt,
                )
                .having((error) => error.name, 'name', 'modifiedAt'),
          ),
        );
      });
    });
  });
}

/// Concrete entity used to exercise the abstract audited constructor.
@MappableClass()
final class TestAuditedEntity extends AuditedEntity
    with TestAuditedEntityMappable {
  TestAuditedEntity({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
  });
}
