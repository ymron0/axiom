@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/failures/database_close_failure.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseCloseFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = DatabaseCloseFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The database could not be closed.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = DatabaseCloseFailure();

      // Then
      expect(failure.type, DatabaseCloseFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = DatabaseCloseFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
