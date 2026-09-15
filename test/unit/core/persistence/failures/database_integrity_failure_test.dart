@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/persistence/failures/database_integrity_failure.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseIntegrityFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = DatabaseIntegrityFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The database failed its integrity check.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = DatabaseIntegrityFailure();

      // Then
      expect(failure.type, DatabaseIntegrityFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = DatabaseIntegrityFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
