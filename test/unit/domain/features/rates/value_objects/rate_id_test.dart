import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('RateId', () {
    test('fromString preserves the supplied identifier value', () {
      // Given
      const value = 'rate-123';

      // When
      final id = RateId.fromString(value);

      // Then
      expect(id.value, value);
    });

    test('fromString rejects empty and whitespace-only values', () {
      // Given
      const invalidValues = ['', ' ', '\t', '\n'];

      // When / Then
      for (final value in invalidValues) {
        expect(
          () => RateId.fromString(value),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.invalidValue, 'invalidValue', value)
                .having((error) => error.name, 'name', 'value'),
          ),
          reason: 'Expected ${value.runes} to be rejected.',
        );
      }
    });

    test('generated IDs round trip through dart_mappable serialization', () {
      // Given
      final generated = RateId.generate();

      // When
      final decoded = RateIdMapper.fromJson(generated.toJson());

      // Then
      expect(decoded, generated);
      expect(decoded, isA<RateId>());
    });

    test('generated IDs use typed value equality', () {
      // Given
      final generated = RateId.generate();
      final equivalent = RateId.fromString(generated.value);
      final differentType = AssetId.fromString(generated.value);

      // Then
      expect(generated, equivalent);
      expect(generated.hashCode, equivalent.hashCode);
      expect(generated, isNot(differentType));
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      // Given / When
      final id = RateId.generate();

      // Then
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
