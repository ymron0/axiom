@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/migrations/database_migrations.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseSchema', () {
    test('keeps the released schema version at 1', () {
      // Given
      const expectedVersion = 1;

      // When
      const version = DatabaseSchema.version;

      // Then
      expect(version, expectedVersion);
    });

    test('uses the application database file name', () {
      // Given
      const expectedFileName = 'app.db';

      // When
      const fileName = DatabaseSchema.fileName;

      // Then
      expect(fileName, expectedFileName);
    });

    test('has a default migration registry valid for the schema version', () {
      // Given
      final migrations = DatabaseMigrations.all;

      // When / Then
      expect(migrations.length, DatabaseSchema.version - 1);
      expect(() => DatabaseMigrator(), returnsNormally);
    });
  });
}
