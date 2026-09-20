@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/failures/database_version_failure.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseVersionFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = DatabaseVersionFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The database schema version is unsupported.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = DatabaseVersionFailure();

      // Then
      expect(failure.type, DatabaseVersionFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = DatabaseVersionFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
