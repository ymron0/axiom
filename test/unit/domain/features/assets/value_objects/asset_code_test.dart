import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  group('AssetCode', () {
    group('construction', () {
      test('trims surrounding whitespace', () {
        // Given
        const value = '  EUR  ';

        // When
        final code = AssetCode(value);

        // Then
        expect(code.value, 'EUR');
      });

      test('preserves a generic non-whitespace value', () {
        // Given
        const value = 'EUR';

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
              'Asset code cannot be empty',
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
  });
}
