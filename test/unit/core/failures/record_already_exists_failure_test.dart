import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RecordAlreadyExistsFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = RecordAlreadyExistsFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The record already exists.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = RecordAlreadyExistsFailure();

      // Then
      expect(failure.type, RecordAlreadyExistsFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = RecordAlreadyExistsFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
