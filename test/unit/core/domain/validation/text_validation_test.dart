import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeOptionalText', () {
    test('returns null when the value is omitted', () {
      // Given / When
      final result = normalizeOptionalText(null, 'description');

      // Then
      expect(result, isNull);
    });

    test('trims supplied text', () {
      // Given / When
      final result = normalizeOptionalText('  description  ', 'description');

      // Then
      expect(result, 'description');
    });

    test('rejects text that is blank after trimming', () {
      // Given / When / Then
      expect(
        () => normalizeOptionalText('  ', 'description'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'description',
          ),
        ),
      );
    });
  });
}
