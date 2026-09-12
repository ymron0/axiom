import 'package:axiom/src/core/domain/entities/base/identified_entity.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/domain/value_objects/test_unique_id.dart';

part 'identified_entity_test.mapper.dart';

void main() {
  group('IdentifiedEntity', () {
    group('construction', () {
      test('preserves its identifier and entity version', () {
        // Given
        final id = TestUniqueId('entity-id');

        // When
        final entity = TestIdentifiedEntity(id: id, entityVersion: 7);

        // Then
        expect(entity.id, same(id));
        expect(entity.entityVersion, 7);
      });

      test('rejects an invalid inherited entity version', () {
        // Given
        final id = TestUniqueId('entity-id');

        // When
        TestIdentifiedEntity construct() =>
            TestIdentifiedEntity(id: id, entityVersion: 0);

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.invalidValue, 'invalidValue', 0)
                .having((error) => error.name, 'name', 'entityVersion'),
          ),
        );
      });
    });
  });
}

/// Concrete entity used to exercise the abstract identified constructor.
@MappableClass()
final class TestIdentifiedEntity extends IdentifiedEntity<TestUniqueId>
    with TestIdentifiedEntityMappable {
  TestIdentifiedEntity({required super.id, required super.entityVersion});
}
