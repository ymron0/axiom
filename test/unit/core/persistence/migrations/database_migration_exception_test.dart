@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/migrations/database_migration_exception.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseMigrationException', () {
    test('preserves fromVersion', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 1,
        toVersion: 2,
        message: 'Migration failed.',
      );

      // Then
      expect(exception.fromVersion, 1);
    });

    test('preserves toVersion', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 1,
        toVersion: 2,
        message: 'Migration failed.',
      );

      // Then
      expect(exception.toVersion, 2);
    });

    test('preserves message', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 1,
        toVersion: 2,
        message: 'Migration failed.',
      );

      // Then
      expect(exception.message, 'Migration failed.');
    });

    test('toString identifies the exception type', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 1,
        toVersion: 2,
        message: 'Migration failed.',
      );

      // When
      final description = exception.toString();

      // Then
      expect(description, contains('DatabaseMigrationException'));
    });

    test('toString includes the source version', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 7,
        toVersion: 8,
        message: 'Migration failed.',
      );

      // When
      final description = exception.toString();

      // Then
      expect(description, contains('7'));
    });

    test('toString includes the target version', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 7,
        toVersion: 8,
        message: 'Migration failed.',
      );

      // When
      final description = exception.toString();

      // Then
      expect(description, contains('8'));
    });

    test('toString includes the diagnostic message', () {
      // Given
      const exception = DatabaseMigrationException(
        fromVersion: 1,
        toVersion: 2,
        message: 'Migration failed.',
      );

      // When
      final description = exception.toString();

      // Then
      expect(description, contains('Migration failed.'));
    });
  });
}
