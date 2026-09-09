import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RecordNotFoundFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = RecordNotFoundFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The record was not found.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = RecordNotFoundFailure();

      // Then
      expect(failure.type, RecordNotFoundFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = RecordNotFoundFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
