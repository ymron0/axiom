@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/persistence/failures/database_migration_failure.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseMigrationFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = DatabaseMigrationFailure.new;

    test('preserves the source schema version', () {
      // Given
      const fromVersion = 1;

      // When
      final failure = createFailure(fromVersion: fromVersion, toVersion: 2);

      // Then
      expect(failure.fromVersion, fromVersion);
    });

    test('preserves the target schema version', () {
      // Given
      const toVersion = 2;

      // When
      final failure = createFailure(fromVersion: 1, toVersion: toVersion);

      // Then
      expect(failure.toVersion, toVersion);
    });

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure(fromVersion: 1, toVersion: 2);

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The database migration failed.';

      // When
      final failure = createFailure(
        fromVersion: 1,
        toVersion: 2,
        message: message,
      );

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = DatabaseMigrationFailure(fromVersion: 1, toVersion: 2);

      // Then
      expect(failure.type, DatabaseMigrationFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = DatabaseMigrationFailure(fromVersion: 1, toVersion: 2);

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
