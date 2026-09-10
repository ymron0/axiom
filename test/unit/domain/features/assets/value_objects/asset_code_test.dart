import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  group('AssetCode', () {
    group('construction', () {
      test('trims surrounding whitespace and preserves case', () {
        // Given
        const value = '  eUr  ';

        // When
        final code = AssetCode(value);

        // Then
        expect(code.value, 'eUr');
      });

      test('preserves lowercase values', () {
        // Given
        const value = 'btc';

        // When
        final code = AssetCode(value);

        // Then
        expect(code.value, value);
      });

      test('rejects an empty value', () {
        // Given
        const value = '';

        // When / Then
        expect(
          () => AssetCode(value),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Asset code cannot be blank.',
            ),
          ),
        );
      });

      test('rejects a whitespace-only value', () {
        // Given
        const value = ' \t\n ';

        // When / Then
        expect(() => AssetCode(value), throwsA(isA<ArgumentError>()));
      });
    });

    test('returns its value from toString', () {
      // Given
      final code = AssetCode('EUR');

      // When / Then
      expect(code.toString(), 'EUR');
    });

    test('compares equivalent trimmed values as equal', () {
      // Given
      final lowercase = AssetCode(' eur ');
      final trimmed = AssetCode('eur');

      // Then
      expect(lowercase, trimmed);
    });

    test('compares codes with different casing as unequal', () {
      // Given
      final lowercase = AssetCode('eur');
      final uppercase = AssetCode('EUR');

      // Then
      expect(lowercase, isNot(uppercase));
    });
  });
}
