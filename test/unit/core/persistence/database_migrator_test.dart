@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseMigrator', () {
    test('0 to 1 completes successfully', () async {
      // Given
      final database = await _openDatabase();

      // When / Then
      await expectLater(
        const DatabaseMigrator().migrate(database, 0, 1),
        completes,
      );
    });

    test('1 to 1 completes without migration work', () async {
      // Given
      final database = await _openDatabase();
      final migrator = DatabaseMigrator(
        migrations: [
          (_) async => fail('The version 1 migration must not run.'),
        ],
      );

      // When / Then
      await expectLater(migrator.migrate(database, 1, 1), completes);
    });

    test('2 to 1 throws UnsupportedDatabaseVersionException', () async {
      // Given
      final database = await _openDatabase();

      // When / Then
      await expectLater(
        const DatabaseMigrator().migrate(database, 2, 1),
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

    test('rejects a downgrade before executing any migration step', () async {
      // Given
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = DatabaseMigrator(
        migrations: [
          (_) async => executedVersions.add(1),
          (_) async => executedVersions.add(2),
          (_) async => executedVersions.add(3),
        ],
      );

      // When
      await expectLater(
        migrator.migrate(database, 2, 1),
        throwsA(isA<UnsupportedDatabaseVersionException>()),
      );

      // Then
      expect(executedVersions, isEmpty);
    });

    test('executes intermediate migrations in ascending order', () async {
      // Given
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = DatabaseMigrator(
        migrations: [
          (_) async => executedVersions.add(1),
          (_) async => executedVersions.add(2),
          (_) async => executedVersions.add(3),
        ],
      );

      // When
      await migrator.migrate(database, 0, 3);

      // Then
      expect(executedVersions, [1, 2, 3]);
    });
  });
}

Future<Database> _openDatabase() async {
  final database = await databaseFactoryMemory.openDatabase(
    'database-migrator-test-${DateTime.now().microsecondsSinceEpoch}',
  );
  addTearDown(database.close);
  return database;
}
