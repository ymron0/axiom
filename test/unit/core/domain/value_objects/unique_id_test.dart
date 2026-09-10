import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

import '../../../../fixtures/core/domain/value_objects/test_unique_id.dart';

part 'unique_id_test.mapper.dart';

void main() {
  group('UniqueId', () {
    group('construction', () {
      test('preserves a supplied nonblank value', () {
        const value = '  existing-id  ';

        final id = TestUniqueId(value);

        expect(id.value, value);
      });

      test('throws ArgumentError when the supplied value is blank', () {
        const blankValues = ['', ' ', '\t', '\n'];

        for (final value in blankValues) {
          expect(
            () => TestUniqueId(value),
            throwsA(
              isA<ArgumentError>()
                  .having((error) => error.invalidValue, 'invalidValue', value)
                  .having((error) => error.name, 'name', 'value'),
            ),
            reason: 'Expected ${value.runes} to be rejected.',
          );
        }
      });

      test('mapper round trips a valid identifier without changing its value', () {
        const value = '  existing-id  ';
        final id = TestUniqueId(value);

        final decoded = TestUniqueIdMapper.fromJson(id.toJson());

        expect(decoded.value, value);
        expect(decoded, id);
      });

      test('copyWith rejects a blank replacement value', () {
        final id = TestUniqueId('existing-id');

        expect(
          () => id.copyWith(value: ''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('generate', () {
      test('uses only characters from the Nano ID URL alphabet', () {
        final id = TestUniqueId.generate();
        final allowedCharacters = urlAlphabet.split('');

        expect(id.value, isNotEmpty);
        expect(id.value.split(''), everyElement(isIn(allowedCharacters)));
      });
    });

    group('equality', () {
      test('equal values of the same subtype are equal', () {
        final first = TestUniqueId('same-id');
        final second = TestUniqueId('same-id');

        expect(first, second);
        expect(first.hashCode, second.hashCode);
      });

      test('different values of the same subtype are not equal', () {
        final first = TestUniqueId('first-id');
        final second = TestUniqueId('second-id');

        expect(first, isNot(second));
      });

      test('equal values of different subtypes are not equal', () {
        final first = TestUniqueId('same-id');
        final second = OtherTestUniqueId('same-id');

        expect(first, isNot(second));
      });
    });
  });
}

/// Alternate identifier used to verify subtype-sensitive equality.
@MappableClass()
final class OtherTestUniqueId extends UniqueId with OtherTestUniqueIdMappable {
  OtherTestUniqueId(super.value);
}
