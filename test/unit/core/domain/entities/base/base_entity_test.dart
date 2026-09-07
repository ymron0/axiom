import 'package:axiom/src/core/domain/entities/base/base_entity.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:test/test.dart';

part 'base_entity_test.mapper.dart';

void main() {
  group('BaseEntity', () {
    group('construction', () {
      test('preserves valid entity versions', () {
        // Given
        const versions = [1, 2, 42];

        // When
        final entities = versions.map(TestBaseEntity.new);

        // Then
        expect(
          entities.map((entity) => entity.entityVersion),
          orderedEquals(versions),
        );
      });

      test('throws ArgumentError when the entity version is invalid', () {
        // Given
        const invalidVersions = [0, -1];

        for (final version in invalidVersions) {
          // When
          TestBaseEntity construct() => TestBaseEntity(version);

          // Then
          expect(
            construct,
            throwsA(
              isA<ArgumentError>()
                  .having(
                    (error) => error.invalidValue,
                    'invalidValue',
                    version,
                  )
                  .having((error) => error.name, 'name', 'entityVersion'),
            ),
            reason: 'Expected version $version to be rejected.',
          );
        }
      });
    });
  });
}

/// Concrete entity used to exercise the abstract base constructor.
@MappableClass()
final class TestBaseEntity extends BaseEntity with TestBaseEntityMappable {
  TestBaseEntity(super.entityVersion);
}
