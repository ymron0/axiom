@Tags(['core', 'persistence'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/failures/database_open_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_version_failure.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import '../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../mocks/database_factory_mock.dart';

const _recordKey = 'persistence-test-record';
const _record = <String, Object?>{'value': 'persisted'};

void main() {
  group('PersistenceTestEnvironment', () {
    group('creation', () {
      test(
        'createMemory creates an existing unique parent temporary directory',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();

          // When
          final parentExists = await environment.parentDirectory.exists();

          // Then
          expect(parentExists, isTrue);
          expect(environment.parentDirectory.path, isNotEmpty);
        },
      );

      test(
        'createMemory does not create rootDirectory during construction',
        () async {
          // Given / When
          final environment = await PersistenceTestEnvironment.createMemory();

          // Then
          expect(await environment.rootDirectory.exists(), isFalse);
        },
      );

      test('independently created environments never share paths', () async {
        // Given
        final first = await PersistenceTestEnvironment.createMemory();
        final second = await PersistenceTestEnvironment.createMemory();

        // Then
        expect(
          first.parentDirectory.path,
          isNot(equals(second.parentDirectory.path)),
        );
        expect(first.databasePath, isNot(equals(second.databasePath)));
      });

      test('an empty prefix throws ArgumentError', () async {
        // When / Then
        await expectLater(
          PersistenceTestEnvironment.createMemory(prefix: ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('a whitespace-only prefix throws ArgumentError', () async {
        // When / Then
        await expectLater(
          PersistenceTestEnvironment.createMemory(prefix: '   '),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('paths', () {
      test('databasePath ends with the schema file name', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();

        // Then
        expect(
          environment.databasePath.endsWith(DatabaseSchema.fileName),
          isTrue,
        );
      });

      test('databaseFile.path equals databasePath', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();

        // Then
        expect(environment.databaseFile.path, equals(environment.databasePath));
      });
    });

    group('database creation', () {
      test('createDatabase returns a closed SembastDatabase', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();

        // When
        final database = environment.createDatabase();

        // Then
        expect(database.isOpen, isFalse);
      });

      test('opening a created database creates rootDirectory', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        final database = environment.createDatabase();
        expect(await environment.rootDirectory.exists(), isFalse);

        // When
        await database.open();

        // Then
        expect(await environment.rootDirectory.exists(), isTrue);
      });

      test('opening a created database uses DatabaseSchema.version', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        final database = environment.createDatabase();

        // When
        final openedDatabase = await database.open();

        // Then
        expect(openedDatabase.version, equals(DatabaseSchema.version));
      });

      test('createWithFactory uses the supplied DatabaseFactory', () async {
        // Given
        final factory = MockDatabaseFactory();
        final environment = await PersistenceTestEnvironment.createWithFactory(
          databaseFactory: factory,
        );
        final rawDatabase = await databaseFactoryMemory.openDatabase(
          p.join(environment.rootDirectory.path, 'factory-result.db'),
          version: DatabaseSchema.version,
        );
        when(
          () => factory.openDatabase(
            any(),
            version: any(named: 'version'),
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async => rawDatabase);
        final database = environment.createDatabase();

        // When
        await database.open();

        // Then
        verify(
          () => factory.openDatabase(
            environment.databasePath,
            version: DatabaseSchema.version,
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: DatabaseMode.create,
          ),
        ).called(1);
      });
    });

    group('lifecycle and raw databases', () {
      test('createLifecycle returns a lifecycle that starts closed', () async {
        // Given / When
        final environment = await PersistenceTestEnvironment.createMemory();
        final lifecycle = environment.createLifecycle();

        // Then
        expect(lifecycle.isOpen, isFalse);
      });

      test(
        'a memory lifecycle can complete its normal open workflow',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final lifecycle = environment.createLifecycle();

          // When
          final result = await lifecycle.open();

          // Then
          expect(result.isSuccess, isTrue);
          expect(result.valueOrNull, isNotNull);
          expect(lifecycle.isOpen, isTrue);
        },
      );

      test('openRawDatabase opens at the environment database path', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();

        // When
        final handle = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        // Then
        expect(handle.database.path, equals(environment.databasePath));
      });

      test('openRawDatabase uses the requested version', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        final requestedVersion = DatabaseSchema.version + 1;

        // When
        final handle = await environment.openRawDatabase(
          version: requestedVersion,
        );

        // Then
        expect(handle.database.version, equals(requestedVersion));
      });

      test('a raw handle starts open and isClosed is false', () async {
        // Given / When
        final environment = await PersistenceTestEnvironment.createMemory();
        final handle = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        // Then
        expect(handle.isClosed, isFalse);
      });

      test('closing a raw handle sets isClosed to true', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        final handle = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        // When
        await handle.close();

        // Then
        expect(handle.isClosed, isTrue);
      });

      test('closing a raw handle more than once completes safely', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        final handle = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );
        await handle.close();

        // When / Then
        await expectLater(handle.close(), completes);
      });
    });

    group('disposal', () {
      test(
        'dispose closes a database created through createDatabase',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final database = environment.createDatabase();
          await database.open();

          // When
          await environment.dispose();

          // Then
          expect(database.isOpen, isFalse);
        },
      );

      test(
        'dispose closes a raw database registered through openRawDatabase',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final handle = await environment.openRawDatabase(
            version: DatabaseSchema.version,
          );

          // When
          await environment.dispose();

          // Then
          expect(handle.isClosed, isTrue);
        },
      );

      test(
        'dispose recursively removes the temporary parent directory',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final parentPath = environment.parentDirectory.path;
          await File(
            p.join(parentPath, 'nested', 'file.txt'),
          ).create(recursive: true);

          // When
          await environment.dispose();

          // Then
          expect(await Directory(parentPath).exists(), isFalse);
          final repositoryDatabaseDirectories = Directory.current
              .listSync(recursive: true)
              .whereType<Directory>()
              .where((directory) {
                final name = p.basename(directory.path);
                return name.startsWith('test-') && name.contains('database');
              });
          expect(repositoryDatabaseDirectories, isEmpty);
        },
      );

      test('calling dispose more than once completes safely', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        await environment.dispose();

        // When / Then
        await expectLater(environment.dispose(), completes);
      });
    });

    group('disposed environment boundaries', () {
      test('createDatabase after disposal throws StateError', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        await environment.dispose();

        // When / Then
        expect(environment.createDatabase, throwsA(isA<StateError>()));
      });

      test('createLifecycle after disposal throws StateError', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        await environment.dispose();

        // When / Then
        expect(environment.createLifecycle, throwsA(isA<StateError>()));
      });

      test('openRawDatabase after disposal throws StateError', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        await environment.dispose();

        // When / Then
        await expectLater(
          environment.openRawDatabase(version: DatabaseSchema.version),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('teardown regressions', () {
      test(
        'automatic teardown safely closes an unclosed managed database',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final database = environment.createDatabase();

          // When
          await database.open();

          // Then
          expect(database.isOpen, isTrue);
          // The fixture's registered teardown closes the database after this test.
        },
      );

      test(
        'manually closing a managed database before teardown is safe',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final database = environment.createDatabase();
          await database.open();

          // When
          await database.close();

          // Then
          expect(database.isOpen, isFalse);
        },
      );

      test('manually closing a raw handle before teardown is safe', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory();
        final handle = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        // When
        await handle.close();

        // Then
        expect(handle.isClosed, isTrue);
      });

      test(
        'multiple managed wrappers and raw handles clean up safely',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createMemory();
          final firstDatabase = environment.createDatabase();
          final secondDatabase = environment.createDatabase();
          final firstHandle = await environment.openRawDatabase(
            version: DatabaseSchema.version,
          );

          // When
          await environment.dispose();

          // Then
          expect(firstDatabase.isOpen, isFalse);
          expect(secondDatabase.isOpen, isFalse);
          expect(firstHandle.isClosed, isTrue);
        },
      );

      test(
        'disposal leaves no test database directory in the repository',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          final parentPath = environment.parentDirectory.path;
          expect(p.isWithin(Directory.current.path, parentPath), isFalse);

          // When
          await environment.dispose();

          // Then
          expect(await Directory(parentPath).exists(), isFalse);
        },
      );
    });

    group('IO lifecycle integration', () {
      test(
        'opening an IO lifecycle creates a physical database file',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          expect(await environment.rootDirectory.exists(), isFalse);
          expect(await environment.databaseFile.exists(), isFalse);

          // When
          final result = await environment.createLifecycle().open();

          // Then
          expect(result.isSuccess, isTrue);
          expect(await environment.rootDirectory.exists(), isTrue);
          expect(await environment.databaseFile.exists(), isTrue);
        },
      );

      test('physical data survives close and a fresh lifecycle', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo();
        final firstLifecycle = environment.createLifecycle();
        final firstResult = await firstLifecycle.open();
        final firstDatabase = firstResult.valueOrNull!;
        await SembastStores.settings
            .record(_recordKey)
            .put(firstDatabase, _record);
        await firstLifecycle.close();

        // When
        final secondResult = await environment.createLifecycle().open();

        // Then
        expect(secondResult.isSuccess, isTrue);
        expect(
          await SembastStores.settings
              .record(_recordKey)
              .get(secondResult.valueOrNull!),
          equals(_record),
        );
      });

      test(
        'a fresh lifecycle wrapper retains records after application restart',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          final firstLifecycle = environment.createLifecycle();
          final firstDatabase = (await firstLifecycle.open()).valueOrNull!;
          await SembastStores.settings
              .record(_recordKey)
              .put(firstDatabase, _record);
          await firstLifecycle.close();

          // When
          final restartedLifecycle = environment.createLifecycle();
          final restartedDatabase =
              (await restartedLifecycle.open()).valueOrNull!;

          // Then
          expect(
            await SembastStores.settings
                .record(_recordKey)
                .get(restartedDatabase),
            equals(_record),
          );
        },
      );

      test(
        'a supported raw database opens through production lifecycle unchanged',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          final rawDatabase = await environment.openRawDatabase(
            version: DatabaseSchema.version,
          );
          await SembastStores.settings
              .record(_recordKey)
              .put(rawDatabase.database, _record);
          await rawDatabase.close();

          // When
          final result = await environment.createLifecycle().open();

          // Then
          expect(result.isSuccess, isTrue);
          expect(
            await SembastStores.settings
                .record(_recordKey)
                .get(result.valueOrNull!),
            equals(_record),
          );
        },
      );

      test(
        'a newer raw database is rejected without changing its contents',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          final newerVersion = DatabaseSchema.version + 1;
          final rawDatabase = await environment.openRawDatabase(
            version: newerVersion,
          );
          await SembastStores.settings
              .record(_recordKey)
              .put(rawDatabase.database, _record);
          await rawDatabase.close();
          final bytesBefore = await environment.databaseFile.readAsBytes();

          // When
          final result = await environment.createLifecycle().open();

          // Then
          expect(result.failureOrNull, isA<DatabaseVersionFailure>());
          expect(
            await environment.databaseFile.readAsBytes(),
            equals(bytesBefore),
          );

          final reopened = await environment.openRawDatabase(
            version: newerVersion,
          );
          expect(
            await SembastStores.settings
                .record(_recordKey)
                .get(reopened.database),
            equals(_record),
          );
        },
      );

      test(
        'corrupt physical bytes survive a failed lifecycle opening',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          await environment.rootDirectory.create(recursive: true);
          final originalBytes = utf8.encode(
            'deliberately corrupt database bytes',
          );
          await environment.databaseFile.writeAsBytes(
            originalBytes,
            flush: true,
          );

          // When
          final result = await environment.createLifecycle().open();

          // Then
          expect(result.failureOrNull, isA<DatabaseOpenFailure>());
          expect(
            await environment.databaseFile.readAsBytes(),
            equals(originalBytes),
          );
        },
      );

      test('recovery preserves data written before recovery', () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo();
        final lifecycle = environment.createLifecycle();
        final database = (await lifecycle.open()).valueOrNull!;
        await SembastStores.settings.record(_recordKey).put(database, _record);

        // When
        final recovered = await lifecycle.recover();

        // Then
        expect(recovered.isSuccess, isTrue);
        expect(
          await SembastStores.settings
              .record(_recordKey)
              .get(recovered.valueOrNull!),
          equals(_record),
        );
      });

      test(
        'repeated lifecycle open and close cycles preserve records',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          final lifecycle = environment.createLifecycle();
          final firstDatabase = (await lifecycle.open()).valueOrNull!;
          await SembastStores.settings
              .record(_recordKey)
              .put(firstDatabase, _record);
          await lifecycle.close();

          // When
          final secondDatabase = (await lifecycle.open()).valueOrNull!;
          final secondRecord = await SembastStores.settings
              .record(_recordKey)
              .get(secondDatabase);
          await lifecycle.close();
          final thirdDatabase = (await lifecycle.open()).valueOrNull!;

          // Then
          expect(secondRecord, equals(_record));
          expect(
            await SembastStores.settings.record(_recordKey).get(thirdDatabase),
            equals(_record),
          );
        },
      );

      test(
        'a fresh IO environment proves production opening creates the root',
        () async {
          // Given
          final environment = await PersistenceTestEnvironment.createIo();
          expect(await environment.rootDirectory.exists(), isFalse);

          // When
          final result = await environment.createLifecycle().open();

          // Then
          expect(result.isSuccess, isTrue);
          expect(await environment.rootDirectory.exists(), isTrue);
        },
      );

      test('records in one environment are isolated from another', () async {
        // Given
        final firstEnvironment = await PersistenceTestEnvironment.createIo();
        final secondEnvironment = await PersistenceTestEnvironment.createIo();
        final firstDatabase =
            (await firstEnvironment.createLifecycle().open()).valueOrNull!;
        final secondDatabase =
            (await secondEnvironment.createLifecycle().open()).valueOrNull!;
        await SembastStores.settings
            .record(_recordKey)
            .put(firstDatabase, _record);

        // When
        final secondRecord = await SembastStores.settings
            .record(_recordKey)
            .get(secondDatabase);

        // Then
        expect(secondRecord, isNull);
      });
    });

    group('architecture regressions', () {
      test('persistence tests do not reference the removed helper flow', () {
        // Given
        final forbiddenNames = <String>[
          'start'
              'Database',
          'stop'
              'Database',
          'execute'
              'Operation',
          'get'
              'DatabaseFile',
        ];
        final testFiles = Directory('test')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('_test.dart'));

        // When / Then
        for (final file in testFiles) {
          final source = file.readAsStringSync();
          for (final forbiddenName in forbiddenNames) {
            expect(source, isNot(contains(forbiddenName)), reason: file.path);
          }
        }
      });

      test('production files do not import the persistence test fixture', () {
        // Given
        final productionFiles = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'));

        // When / Then
        for (final file in productionFiles) {
          final source = file.readAsStringSync();
          expect(
            source,
            isNot(contains('test/fixtures/core/persistence')),
            reason: file.path,
          );
        }
      });
    });
  });
}
