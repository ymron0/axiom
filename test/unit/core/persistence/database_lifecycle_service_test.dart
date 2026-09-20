@Tags(['core', 'data', 'persistence'])
library;

import 'dart:async';
import 'dart:io';

import 'package:axiom/src/core/persistence/database_integrity_checker.dart';
import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/failures/database_close_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_integrity_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_migration_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_open_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_recovery_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_version_failure.dart';
import 'package:axiom/src/core/persistence/migrations/database_migration_exception.dart';
import 'package:axiom/src/core/persistence/migrations/database_migration.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import '../../../mocks/database_factory_mock.dart';
import '../../../mocks/database_integrity_checker_mock.dart';

void main() {
  group('DatabaseLifecycleService', () {
    group('opening and state behavior', () {
      test('starts closed', () async {
        // Given
        final harness = await _createHarness();

        // When
        final state = harness.service.isOpen;

        // Then
        expect(state, isFalse);
      });

      test('successful open returns a successful result', () async {
        // Given
        final harness = await _createHarness();

        // When
        final result = await harness.service.open();

        // Then
        expect(result.isSuccess, isTrue);
      });

      test('successful open returns the opened Database', () async {
        // Given
        final harness = await _createHarness();

        // When
        final result = await harness.service.open();

        // Then
        expect(result.valueOrNull, same(harness.rawDatabase));
      });

      test(
        'state becomes open only after integrity validation succeeds',
        () async {
          // Given
          final harness = await _createHarness();
          final validation = Completer<int>();
          harness.stubValidation(validation.future);

          // When
          final opening = harness.service.open();
          await untilCalled(() => harness.store.txnCount(null, null));

          // Then
          expect(harness.service.isOpen, isFalse);

          // When
          validation.complete(0);
          await opening;

          // Then
          expect(harness.service.isOpen, isTrue);
        },
      );

      test('calling open twice returns the same validated database', () async {
        // Given
        final harness = await _createHarness();

        // When
        final first = await harness.service.open();
        final second = await harness.service.open();

        // Then
        expect(first.valueOrNull, same(second.valueOrNull));
        verify(() => harness.store.txnCount(null, null)).called(1);
      });

      test(
        'repeated open does not create a second raw database instance',
        () async {
          // Given
          final harness = await _createHarness();

          // When
          await harness.service.open();
          await harness.service.open();

          // Then
          verify(
            () => harness.factory.openDatabase(
              any(),
              version: any(named: 'version'),
              onVersionChanged: any(named: 'onVersionChanged'),
              mode: any(named: 'mode'),
            ),
          ).called(1);
        },
      );

      test(
        'concurrent open calls share the same lifecycle operation',
        () async {
          // Given
          final harness = await _createHarness();
          final validation = Completer<int>();
          harness.stubValidation(validation.future);

          // When
          final firstOpening = harness.service.open();
          final secondOpening = harness.service.open();
          await untilCalled(() => harness.store.txnCount(null, null));
          validation.complete(0);
          final results = await Future.wait([firstOpening, secondOpening]);

          // Then
          expect(results, everyElement(isA<Success<Database>>()));
          verify(() => harness.store.txnCount(null, null)).called(1);
          verify(
            () => harness.factory.openDatabase(
              any(),
              version: any(named: 'version'),
              onVersionChanged: any(named: 'onVersionChanged'),
              mode: any(named: 'mode'),
            ),
          ).called(1);
        },
      );

      test(
        'concurrent open calls receive the same Database instance',
        () async {
          // Given
          final harness = await _createHarness();

          // When
          final results = await Future.wait([
            harness.service.open(),
            harness.service.open(),
          ]);

          // Then
          expect(results[0].valueOrNull, same(results[1].valueOrNull));
          expect(results[0].valueOrNull, same(harness.rawDatabase));
        },
      );

      test(
        'integrity validation observes the final migrated database schema',
        () async {
          // Given
          final events = <String>[];
          final store = stringMapStoreFactory.store('migrated');
          final harness = await _createMigrationHarness(
            store: store,
            migration: (_) async => events.add('migration'),
          );
          when(() => harness.store.txnCount(null, null)).thenAnswer((_) async {
            events.add('integrity');
            return 0;
          });

          // When
          final result = await harness.service.open();

          // Then
          expect(result.isSuccess, isTrue);
          expect(events, ['migration', 'integrity']);
        },
      );

      test(
        'integrity validation never runs before migration completes',
        () async {
          // Given
          final events = <String>[];
          final store = stringMapStoreFactory.store('migrated');
          final harness = await _createMigrationHarness(
            store: store,
            migration: (_) async {
              expect(events, isEmpty);
              events.add('migration');
            },
          );
          when(() => harness.store.txnCount(null, null)).thenAnswer((_) async {
            expect(events, ['migration']);
            events.add('integrity');
            return 0;
          });

          // When
          final result = await harness.service.open();

          // Then
          expect(result.isSuccess, isTrue);
          expect(events, ['migration', 'integrity']);
        },
      );

      test('a successfully migrated but structurally invalid database returns '
          'DatabaseIntegrityFailure', () async {
        // Given
        final events = <String>[];
        final store = stringMapStoreFactory.store('actual');
        final harness = await _createMigrationHarness(
          store: store,
          migration: (_) async => events.add('migration'),
          storeNames: ['declared'],
        );

        // When
        final result = await harness.service.open();

        // Then
        expect(result, isA<DatabaseIntegrityFailure>());
        expect(events, ['migration']);
        expect(harness.service.isOpen, isFalse);
      });

      test(
        'an already-open raw database is validated before exposure',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.database.open();
          final validation = Completer<int>();
          harness.stubValidation(validation.future);

          // When
          final opening = harness.service.open();
          await untilCalled(() => harness.store.txnCount(null, null));

          // Then
          expect(harness.service.isOpen, isFalse);
          expect(harness.service.isOpen, isFalse);

          // When
          validation.complete(0);
          final result = await opening;

          // Then
          expect(result.valueOrNull, same(harness.rawDatabase));
          expect(harness.service.isOpen, isTrue);
        },
      );

      test(
        'UnsupportedDatabaseVersionException becomes DatabaseVersionFailure',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubOpenError(
            const UnsupportedDatabaseVersionException(
              existingVersion: 3,
              supportedVersion: 1,
            ),
          );

          // When
          final result = await harness.service.open();

          // Then
          expect(result, isA<DatabaseVersionFailure>());
        },
      );

      test('DatabaseVersionFailure preserves existingVersion', () async {
        // Given
        final harness = await _createHarness();
        harness.stubOpenError(
          const UnsupportedDatabaseVersionException(
            existingVersion: 3,
            supportedVersion: 1,
          ),
        );

        // When
        final result = await harness.service.open();

        // Then
        if (result.failureOrNull case final DatabaseVersionFailure failure) {
          expect(failure.existingVersion, 3);
        } else {
          fail('Expected a DatabaseVersionFailure.');
        }
      });

      test('DatabaseVersionFailure preserves supportedVersion', () async {
        // Given
        final harness = await _createHarness();
        harness.stubOpenError(
          const UnsupportedDatabaseVersionException(
            existingVersion: 3,
            supportedVersion: 1,
          ),
        );

        // When
        final result = await harness.service.open();

        // Then
        if (result.failureOrNull case final DatabaseVersionFailure failure) {
          expect(failure.supportedVersion, 1);
        } else {
          fail('Expected a DatabaseVersionFailure.');
        }
      });

      test(
        'DatabaseMigrationException becomes DatabaseMigrationFailure',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubOpenError(
            const DatabaseMigrationException(
              fromVersion: 1,
              toVersion: 2,
              message: 'The migration could not transform the records safely.',
            ),
          );

          // When
          final result = await harness.service.open();

          // Then
          expect(result, isA<DatabaseMigrationFailure>());
          expect(result, isNot(isA<DatabaseOpenFailure>()));
          expect(result, isNot(isA<DatabaseVersionFailure>()));
          expect(result.valueOrNull, isNull);
          expect(harness.service.isOpen, isFalse);
          verifyNever(() => harness.store.txnCount(null, null));
        },
      );

      test('DatabaseMigrationFailure preserves fromVersion', () async {
        // Given
        final harness = await _createHarness();
        harness.stubOpenError(
          const DatabaseMigrationException(
            fromVersion: 4,
            toVersion: 5,
            message: 'Safe migration diagnostic.',
          ),
        );

        // When
        final result = await harness.service.open();

        // Then
        if (result.failureOrNull case final DatabaseMigrationFailure failure) {
          expect(failure.fromVersion, 4);
        } else {
          fail('Expected a DatabaseMigrationFailure.');
        }
      });

      test('DatabaseMigrationFailure preserves toVersion', () async {
        // Given
        final harness = await _createHarness();
        harness.stubOpenError(
          const DatabaseMigrationException(
            fromVersion: 4,
            toVersion: 5,
            message: 'Safe migration diagnostic.',
          ),
        );

        // When
        final result = await harness.service.open();

        // Then
        if (result.failureOrNull case final DatabaseMigrationFailure failure) {
          expect(failure.toVersion, 5);
        } else {
          fail('Expected a DatabaseMigrationFailure.');
        }
      });

      test(
        'DatabaseMigrationFailure preserves the safe diagnostic message',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubOpenError(
            const DatabaseMigrationException(
              fromVersion: 4,
              toVersion: 5,
              message: 'Safe migration diagnostic.',
            ),
          );

          // When
          final result = await harness.service.open();

          // Then
          if (result.failureOrNull
              case final DatabaseMigrationFailure failure) {
            expect(failure.message, 'Safe migration diagnostic.');
          } else {
            fail('Expected a DatabaseMigrationFailure.');
          }
        },
      );

      test(
        'FileSystemException during open becomes DatabaseOpenFailure',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubOpenError(const FileSystemException('open failed'));

          // When
          final result = await harness.service.open();

          // Then
          expect(result, isA<DatabaseOpenFailure>());
        },
      );

      test(
        'FileSystemException during directory creation becomes DatabaseOpenFailure',
        () async {
          // Given
          final parentDirectory = await Directory.systemTemp.createTemp(
            'database-lifecycle-service-directory-test-',
          );
          final rootFile = File(p.join(parentDirectory.path, 'database-root'));
          await rootFile.create();
          addTearDown(() => parentDirectory.delete(recursive: true));

          final database = SembastDatabase(
            databaseFactory: MockDatabaseFactory(),
            rootPath: rootFile.path,
          );
          final service = DatabaseLifecycleService(database: database);

          // When
          final result = await service.open();

          // Then
          expect(result, isA<DatabaseOpenFailure>());
        },
      );

      test(
        'DatabaseException during open becomes DatabaseOpenFailure',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubOpenError(DatabaseException.closed('open failed'));

          // When
          final result = await harness.service.open();

          // Then
          expect(result, isA<DatabaseOpenFailure>());
        },
      );

      test('FormatException during open becomes DatabaseOpenFailure', () async {
        // Given
        final harness = await _createHarness();
        harness.stubOpenError(const FormatException('malformed database'));

        // When
        final result = await harness.service.open();

        // Then
        expect(result, isA<DatabaseOpenFailure>());
      });

      test(
        'integrity-checker failure is returned as DatabaseIntegrityFailure',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubValidationError(
            DatabaseException.closed('integrity check failed'),
          );

          // When
          final result = await harness.service.open();

          // Then
          expect(result, isA<DatabaseIntegrityFailure>());
        },
      );

      test('integrity failure closes the raw database', () async {
        // Given
        final harness = await _createHarness();
        harness.stubValidationError(
          DatabaseException.closed('integrity check failed'),
        );

        // When
        await harness.service.open();

        // Then
        verify(() => harness.rawDatabase.close()).called(1);
      });

      test('lifecycle remains closed after integrity failure', () async {
        // Given
        final harness = await _createHarness();
        harness.stubValidationError(
          DatabaseException.closed('integrity check failed'),
        );

        // When
        await harness.service.open();

        // Then
        expect(harness.service.isOpen, isFalse);
      });

      test(
        'close failure following integrity failure becomes DatabaseRecoveryFailure',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubValidationError(
            DatabaseException.closed('integrity check failed'),
          );
          harness.stubCloseError(const FileSystemException('close failed'));

          // When
          final result = await harness.service.open();

          // Then
          expect(result, isA<DatabaseRecoveryFailure>());
          expect(harness.service.isOpen, isFalse);
        },
      );

      test('DatabaseException while closing after integrity failure becomes '
          'DatabaseRecoveryFailure', () async {
        // Given
        final harness = await _createHarness();
        harness.stubValidationError(
          DatabaseException.closed('integrity check failed'),
        );
        harness.stubCloseError(DatabaseException.closed('close failed'));

        // When
        final result = await harness.service.open();

        // Then
        expect(result, isA<DatabaseRecoveryFailure>());
        expect(harness.service.isOpen, isFalse);
      });

      test('ArgumentError from an injected dependency propagates', () async {
        // Given
        final harness = await _createHarness();
        final error = ArgumentError('programmer error');
        harness.stubOpenError(error);

        // When / Then
        await expectLater(harness.service.open(), throwsA(same(error)));
      });

      test(
        'unexpected StateError from an injected dependency propagates',
        () async {
          // Given
          final harness = await _createHarness();
          final error = StateError('programmer error');
          harness.stubOpenError(error);

          // When / Then
          await expectLater(harness.service.open(), throwsA(same(error)));
        },
      );

      test(
        'stale validated state is discarded after the raw database closes',
        () async {
          // Given
          final harness = await _createHarness(rawDatabases: 2);
          final firstResult = await harness.service.open();
          await harness.database.close();

          // When
          final secondResult = await harness.service.open();

          // Then
          expect(firstResult.valueOrNull, same(harness.rawDatabases[0]));
          expect(secondResult.valueOrNull, same(harness.rawDatabases[1]));
          expect(
            secondResult.valueOrNull,
            isNot(same(firstResult.valueOrNull)),
          );
          verify(
            () => harness.factory.openDatabase(
              any(),
              version: any(named: 'version'),
              onVersionChanged: any(named: 'onVersionChanged'),
              mode: any(named: 'mode'),
            ),
          ).called(2);
          verify(() => harness.store.txnCount(null, null)).called(2);
        },
      );
    });

    group('recovery behavior', () {
      test('recover() from a closed database performs a normal open', () async {
        // Given
        final harness = await _createHarness();

        // When
        final result = await harness.service.recover();

        // Then
        expect(result, isA<Success<Database>>());
        expect(result.valueOrNull, same(harness.rawDatabase));
      });

      test('recover() from an open database closes it first', () async {
        // Given
        final harness = await _createHarness(rawDatabases: 2);
        await harness.service.open();

        // When
        final result = await harness.service.recover();

        // Then
        expect(result.isSuccess, isTrue);
        verify(() => harness.rawDatabases.first.close()).called(1);
      });

      test('recovery reruns integrity validation', () async {
        // Given
        final harness = await _createHarness(rawDatabases: 2);
        await harness.service.open();

        // When
        await harness.service.recover();

        // Then
        verify(() => harness.store.txnCount(null, null)).called(2);
      });

      test('successful recovery returns the reopened database', () async {
        // Given
        final harness = await _createHarness(rawDatabases: 2);
        await harness.service.open();

        // When
        final result = await harness.service.recover();

        // Then
        expect(result.valueOrNull, same(harness.rawDatabases[1]));
      });

      test('successful recovery leaves state open', () async {
        // Given
        final harness = await _createHarness(rawDatabases: 2);
        await harness.service.open();

        // When
        await harness.service.recover();

        // Then
        expect(harness.service.isOpen, isTrue);
      });

      test(
        'close failure during recovery returns DatabaseRecoveryFailure',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.service.open();
          harness.stubCloseError(const FileSystemException('close failed'));

          // When
          final result = await harness.service.recover();

          // Then
          expect(result, isA<DatabaseRecoveryFailure>());
        },
      );

      test('cleanup failure prevents the subsequent open attempt', () async {
        // Given
        final harness = await _createHarness(rawDatabases: 2);
        await harness.service.open();
        harness.stubCloseError(const FileSystemException('close failed'));

        // When
        await harness.service.recover();

        // Then
        verify(
          () => harness.factory.openDatabase(
            any(),
            version: any(named: 'version'),
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: any(named: 'mode'),
          ),
        ).called(1);
      });

      test(
        'after successful cleanup, DatabaseOpenFailure from reopen is preserved unchanged',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.service.open();
          harness.stubOpenError(DatabaseException.closed('reopen failed'));

          // When
          final result = await harness.service.recover();

          // Then
          expect(result, isA<DatabaseOpenFailure>());
          expect(
            result.failureOrNull?.message,
            'Failed to open the local database.',
          );
        },
      );

      test(
        'after successful cleanup, DatabaseVersionFailure is preserved unchanged',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.service.open();
          harness.stubOpenError(
            const UnsupportedDatabaseVersionException(
              existingVersion: 3,
              supportedVersion: 1,
            ),
          );

          // When
          final result = await harness.service.recover();

          // Then
          if (result.failureOrNull case final DatabaseVersionFailure failure) {
            expect(failure.existingVersion, 3);
            expect(failure.supportedVersion, 1);
          } else {
            fail('Expected a DatabaseVersionFailure.');
          }
        },
      );

      test(
        'after successful cleanup, DatabaseIntegrityFailure is preserved unchanged',
        () async {
          // Given
          final harness = await _createHarness(rawDatabases: 2);
          await harness.service.open();
          harness.stubValidationFailureAfterFirst(
            DatabaseException.closed('integrity check failed'),
          );

          // When
          final result = await harness.service.recover();

          // Then
          expect(result, isA<DatabaseIntegrityFailure>());
        },
      );

      test(
        'migration failure during recovery remains DatabaseMigrationFailure',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.service.open();
          harness.stubOpenError(
            const DatabaseMigrationException(
              fromVersion: 1,
              toVersion: 2,
              message: 'Recovery migration is not safe to apply.',
            ),
          );

          // When
          final result = await harness.service.recover();

          // Then
          expect(result, isA<DatabaseMigrationFailure>());
          expect(result, isNot(isA<DatabaseOpenFailure>()));
          expect(result, isNot(isA<DatabaseVersionFailure>()));
          expect(result.valueOrNull, isNull);
          expect(harness.service.isOpen, isFalse);
        },
      );

      test(
        'recovery retries the normal opening workflow after migration failure',
        () async {
          // Given
          final harness = await _createHarness(rawDatabases: 2);
          harness.stubOpenError(
            const DatabaseMigrationException(
              fromVersion: 1,
              toVersion: 2,
              message: 'Transient migration failure.',
            ),
          );
          final failedOpen = await harness.service.open();
          expect(failedOpen, isA<DatabaseMigrationFailure>());
          harness.stubOpenSuccess();

          // When
          final result = await harness.service.recover();

          // Then
          expect(result.valueOrNull, same(harness.rawDatabase));
          expect(harness.service.isOpen, isTrue);
          verify(
            () => harness.factory.openDatabase(
              any(),
              version: any(named: 'version'),
              onVersionChanged: any(named: 'onVersionChanged'),
              mode: any(named: 'mode'),
            ),
          ).called(2);
          verify(() => harness.store.txnCount(null, null)).called(1);
        },
      );

      test('recovery never invokes a delete/reset operation', () async {
        // Given
        final harness = await _createHarness(rawDatabases: 2);

        // When
        await harness.service.recover();

        // Then
        verifyNever(() => harness.factory.deleteDatabase(any()));
      });

      test('persisted records survive recovery', () async {
        // Given
        final rootDirectory = await Directory.systemTemp.createTemp(
          'database-lifecycle-service-persistence-test-',
        );
        final store = stringMapStoreFactory.store('records');
        final database = SembastDatabase(
          databaseFactory: databaseFactoryMemory,
          rootPath: rootDirectory.path,
        );
        final service = DatabaseLifecycleService(
          database: database,
          integrityChecker: DatabaseIntegrityChecker(
            storeNames: ['records'],
            stores: [store],
          ),
        );
        addTearDown(() async {
          await service.close();
          if (await rootDirectory.exists()) {
            await rootDirectory.delete(recursive: true);
          }
        });

        final initialResult = await service.open();
        final initialDatabase = initialResult.valueOrNull;
        expect(initialDatabase, isNotNull);
        await store.record('persisted').put(initialDatabase!, {
          'value': 'survives',
        });

        // When
        final recoveryResult = await service.recover();
        final recoveredDatabase = recoveryResult.valueOrNull;

        // Then
        expect(recoveredDatabase, isNotNull);
        expect(await store.record('persisted').get(recoveredDatabase!), {
          'value': 'survives',
        });
      });

      test(
        'recovery can succeed after a transient opening failure is removed',
        () async {
          // Given
          final harness = await _createHarness();
          harness.stubOpenError(DatabaseException.closed('transient failure'));
          final failedRecovery = await harness.service.recover();
          expect(failedRecovery, isA<DatabaseOpenFailure>());
          harness.stubOpenSuccess();

          // When
          final recovered = await harness.service.recover();

          // Then
          expect(recovered.valueOrNull, same(harness.rawDatabase));
          expect(harness.service.isOpen, isTrue);
        },
      );

      test(
        'repeated recovery does not create multiple simultaneously active database instances',
        () async {
          // Given
          final harness = await _createHarness(rawDatabases: 3);
          final events = <String>[];
          harness.trackLifecycleEvents(events);
          await harness.service.open();

          // When
          await harness.service.recover();
          await harness.service.recover();

          // Then
          expect(events, ['open:0', 'close:0', 'open:1', 'close:1', 'open:2']);
          expect(harness.service.isOpen, isTrue);
        },
      );
    });

    group('close behavior', () {
      test('closing an open database succeeds', () async {
        // Given
        final harness = await _createHarness();
        await harness.service.open();

        // When
        final result = await harness.service.close();

        // Then
        expect(result.isSuccess, isTrue);
      });

      test('successful close returns closed state', () async {
        // Given
        final harness = await _createHarness();
        await harness.service.open();

        // When
        await harness.service.close();

        // Then
        expect(harness.service.isOpen, isFalse);
      });

      test('closing an already closed database succeeds', () async {
        // Given
        final harness = await _createHarness();

        // When
        final result = await harness.service.close();

        // Then
        expect(result.isSuccess, isTrue);
        expect(harness.service.isOpen, isFalse);
      });

      test('close waits for an open operation to finish', () async {
        // Given
        final harness = await _createHarness();
        final validation = Completer<int>();
        harness.stubValidation(validation.future);
        var closeCompleted = false;
        final opening = harness.service.open();
        await untilCalled(() => harness.store.txnCount(null, null));

        // When
        final closing = harness.service.close().then((result) {
          closeCompleted = true;
          return result;
        });
        await Future<void>.delayed(Duration.zero);

        // Then
        expect(closeCompleted, isFalse);
        expect(harness.service.isOpen, isFalse);

        // When
        validation.complete(0);
        await opening;
        await closing;

        // Then
        expect(harness.service.isOpen, isFalse);
        expect(closeCompleted, isTrue);
        expect(harness.service.isOpen, isFalse);
      });

      test(
        'FileSystemException while closing returns DatabaseCloseFailure',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.service.open();
          const error = FileSystemException('close failed');
          harness.stubCloseError(error);

          // When
          final result = await harness.service.close();

          // Then
          expect(result, isA<DatabaseCloseFailure>());
          expect(harness.service.isOpen, isFalse);
        },
      );

      test(
        'DatabaseException while closing returns DatabaseCloseFailure',
        () async {
          // Given
          final harness = await _createHarness();
          await harness.service.open();
          final error = DatabaseException.closed('close failed');
          harness.stubCloseError(error);

          // When
          final result = await harness.service.close();

          // Then
          expect(result, isA<DatabaseCloseFailure>());
          expect(harness.service.isOpen, isFalse);
        },
      );

      test('programmer errors while closing are not translated', () async {
        // Given
        final harness = await _createHarness();
        await harness.service.open();
        final error = StateError('programmer error');
        harness.stubCloseError(error);

        // When / Then
        await expectLater(harness.service.close(), throwsA(same(error)));
        expect(harness.service.isOpen, isFalse);
      });

      test('validatedDatabaseOrNull is null before successful open', () async {
        // Given
        final rootDirectory = await _createTemporaryDatabaseRootDirectory();
        addTearDown(() => rootDirectory.delete(recursive: true));
        final database = SembastDatabase(
          databaseFactory: databaseFactoryMemory,
          rootPath: rootDirectory.path,
        );

        final service = DatabaseLifecycleService(database: database);

        // When
        final result = service.validatedDatabaseOrNull;

        // Then
        expect(result, isNull);
      });

      test(
        'validatedDatabaseOrNull exposes database after successful open',
        () async {
          // Given
          final rootDirectory = await _createTemporaryDatabaseRootDirectory();
          final database = SembastDatabase(
            databaseFactory: databaseFactoryMemory,
            rootPath: rootDirectory.path,
          );

          final service = DatabaseLifecycleService(database: database);

          addTearDown(() async {
            await service.close();
            await rootDirectory.delete(recursive: true);
          });

          final openResult = await service.open();

          expect(openResult.isSuccess, isTrue);

          // When
          final validatedDatabase = service.validatedDatabaseOrNull;

          // Then
          expect(validatedDatabase, same(openResult.valueOrNull));
        },
      );

      test('validatedDatabaseOrNull becomes null after close', () async {
        // Given
        final rootDirectory = await _createTemporaryDatabaseRootDirectory();
        addTearDown(() => rootDirectory.delete(recursive: true));
        final database = SembastDatabase(
          databaseFactory: databaseFactoryMemory,
          rootPath: rootDirectory.path,
        );

        final service = DatabaseLifecycleService(database: database);

        final openResult = await service.open();

        expect(openResult.isSuccess, isTrue);
        expect(service.validatedDatabaseOrNull, isNotNull);

        // When
        final closeResult = await service.close();

        // Then
        expect(closeResult.isSuccess, isTrue);
        expect(service.validatedDatabaseOrNull, isNull);
      });
    });
  });
}

Future<Directory> _createTemporaryDatabaseRootDirectory() {
  return Directory.systemTemp.createTemp('database-lifecycle-memory-test-');
}

Future<_LifecycleHarness> _createMigrationHarness({
  required StoreRef<String, Map<String, Object?>> store,
  required Future<void> Function(Transaction transaction) migration,
  List<String>? storeNames,
}) async {
  const migratedVersion = 2;
  final rootDirectory = await Directory.systemTemp.createTemp(
    'database-lifecycle-migration-test-',
  );
  final factory = MockDatabaseFactory();
  final rawDatabase = MockIntegrityDatabaseClient();
  final transaction = MockIntegrityTransaction();
  final integrityStore = MockIntegrityStore();

  when(() => rawDatabase.version).thenReturn(migratedVersion);
  when(() => rawDatabase.getSembastStore(store)).thenReturn(integrityStore);
  when(() => rawDatabase.close()).thenAnswer((_) async {});
  when(() => rawDatabase.transaction<Null>(any())).thenAnswer((
    invocation,
  ) async {
    final action = invocation.positionalArguments.single;
    await action(transaction);
    return null;
  });

  when(
    () => factory.openDatabase(
      any(),
      version: any(named: 'version'),
      onVersionChanged: any(named: 'onVersionChanged'),
      mode: any(named: 'mode'),
    ),
  ).thenAnswer((invocation) async {
    final onVersionChanged = invocation.namedArguments[#onVersionChanged];
    await onVersionChanged(rawDatabase, 1, migratedVersion);
    return rawDatabase;
  });

  final database = SembastDatabase(
    databaseFactory: factory,
    rootPath: rootDirectory.path,
    migrator: DatabaseMigrator(
      supportedVersion: 2,
      migrations: [
        DatabaseMigration(fromVersion: 1, toVersion: 2, operation: migration),
      ],
    ),
  );
  final service = DatabaseLifecycleService(
    database: database,
    integrityChecker: DatabaseIntegrityChecker(
      expectedVersion: migratedVersion,
      storeNames: storeNames ?? [store.name],
      stores: [store],
    ),
  );

  addTearDown(() async {
    await service.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  return _LifecycleHarness(
    factory: factory,
    database: database,
    service: service,
    store: integrityStore,
    rawDatabases: [rawDatabase],
  );
}

Future<_LifecycleHarness> _createHarness({int rawDatabases = 1}) async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'database-lifecycle-service-test-',
  );
  final factory = MockDatabaseFactory();
  final databaseInstances = List<MockIntegrityDatabaseClient>.generate(
    rawDatabases,
    (_) => MockIntegrityDatabaseClient(),
  );
  final store = MockIntegrityStore();
  final storeRef = stringMapStoreFactory.store('lifecycle');

  for (final database in databaseInstances) {
    when(() => database.version).thenReturn(DatabaseSchema.version);
    when(() => database.getSembastStore(storeRef)).thenReturn(store);
    when(() => database.close()).thenAnswer((_) async {});
  }
  when(() => store.txnCount(null, null)).thenAnswer((_) async => 0);

  var openCount = 0;
  when(
    () => factory.openDatabase(
      any(),
      version: any(named: 'version'),
      onVersionChanged: any(named: 'onVersionChanged'),
      mode: any(named: 'mode'),
    ),
  ).thenAnswer((_) async => databaseInstances[openCount++]);

  final database = SembastDatabase(
    databaseFactory: factory,
    rootPath: rootDirectory.path,
  );
  final service = DatabaseLifecycleService(
    database: database,
    integrityChecker: DatabaseIntegrityChecker(
      storeNames: ['lifecycle'],
      stores: [storeRef],
    ),
  );

  addTearDown(() async {
    await service.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  return _LifecycleHarness(
    factory: factory,
    database: database,
    service: service,
    store: store,
    rawDatabases: databaseInstances,
  );
}

final class _LifecycleHarness {
  _LifecycleHarness({
    required this.factory,
    required this.database,
    required this.service,
    required this.store,
    required this.rawDatabases,
  });

  final MockDatabaseFactory factory;
  final SembastDatabase database;
  final DatabaseLifecycleService service;
  final MockIntegrityStore store;
  final List<MockIntegrityDatabaseClient> rawDatabases;

  MockIntegrityDatabaseClient get rawDatabase => rawDatabases.first;

  void stubValidation(Future<int> validation) {
    when(() => store.txnCount(null, null)).thenAnswer((_) => validation);
  }

  void stubValidationError(Object error) {
    when(() => store.txnCount(null, null)).thenThrow(error);
  }

  void stubValidationFailureAfterFirst(Object error) {
    var validationCount = 1;
    when(() => store.txnCount(null, null)).thenAnswer((_) async {
      validationCount++;
      if (validationCount == 2) {
        throw error;
      }
      return 0;
    });
  }

  void stubOpenError(Object error) {
    when(
      () => factory.openDatabase(
        any(),
        version: any(named: 'version'),
        onVersionChanged: any(named: 'onVersionChanged'),
        mode: any(named: 'mode'),
      ),
    ).thenThrow(error);
  }

  void stubOpenSuccess() {
    when(
      () => factory.openDatabase(
        any(),
        version: any(named: 'version'),
        onVersionChanged: any(named: 'onVersionChanged'),
        mode: any(named: 'mode'),
      ),
    ).thenAnswer((_) async => rawDatabases.first);
  }

  void trackLifecycleEvents(List<String> events) {
    var openCount = 0;
    when(
      () => factory.openDatabase(
        any(),
        version: any(named: 'version'),
        onVersionChanged: any(named: 'onVersionChanged'),
        mode: any(named: 'mode'),
      ),
    ).thenAnswer((_) async {
      events.add('open:$openCount');
      return rawDatabases[openCount++];
    });

    for (var index = 0; index < rawDatabases.length; index++) {
      when(() => rawDatabases[index].close()).thenAnswer((_) async {
        events.add('close:$index');
      });
    }
  }

  void stubCloseError(Object error) {
    when(() => rawDatabases.first.close()).thenThrow(error);
  }
}
