@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('UnsupportedDatabaseVersionException', () {
    test('is thrown by DatabaseMigrator with both database versions', () async {
      // Given
      final database = await databaseFactoryMemory.openDatabase(
        'unsupported-database-version-test',
      );
      addTearDown(database.close);

      // When / Then
      await expectLater(
        () => DatabaseMigrator().migrate(database, 2, 1),
        throwsA(
          isA<UnsupportedDatabaseVersionException>()
              .having(
                (exception) => exception.existingVersion,
                'existingVersion',
                2,
              )
              .having(
                (exception) => exception.supportedVersion,
                'supportedVersion',
                1,
              ),
        ),
      );
    });

    test('stores versions and implements Exception', () {
      // Given / When
      const exception = UnsupportedDatabaseVersionException(
        existingVersion: 3,
        supportedVersion: 1,
      );

      // Then
      expect(exception.existingVersion, 3);
      expect(exception.supportedVersion, 1);
      expect(exception, isA<Exception>());
    });
  });
}
