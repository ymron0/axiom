@Tags(['core', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/database_integrity_checker.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/failures/database_integrity_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import '../../../mocks/database_integrity_checker_mock.dart';

void main() {
  group('DatabaseIntegrityChecker', () {
    test('matching database version returns success', () async {
      // Given
      final database = await _openDatabase();
      final checker = DatabaseIntegrityChecker();

      // When
      final result = await checker.check(database);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.failureOrNull, isNull);
    });

    test('returned success contains the exact same Database instance', () async {
      // Given
      final database = await _openDatabase();

      // When
      final result = await DatabaseIntegrityChecker().check(database);

      // Then
      expect(result.valueOrNull, same(database));
    });

    test('empty declared stores pass', () async {
      // Given
      final database = await _openDatabase();
      final checker = DatabaseIntegrityChecker(storeNames: [], stores: []);

      // When
      final result = await checker.check(database);

      // Then
      expect(result.isSuccess, isTrue);
    });

    test('populated declared stores pass', () async {
      // Given
      final database = await _openDatabase();
      final assets = stringMapStoreFactory.store('assets');
      final settings = stringMapStoreFactory.store('settings');
      await assets.record('asset-1').put(database, {'name': 'Checking'});
      await settings.record('settings-1').put(database, {'currency': 'CHF'});
      final checker = DatabaseIntegrityChecker(
        storeNames: ['assets', 'settings'],
        stores: [assets, settings],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result.isSuccess, isTrue);
    });

    test('version lower than expected returns DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase(version: DatabaseSchema.version - 1);

      // When
      final result = await DatabaseIntegrityChecker().check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('version higher than expected returns DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase(version: DatabaseSchema.version + 1);

      // When
      final result = await DatabaseIntegrityChecker().check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('blank store name returns DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase();
      final store = stringMapStoreFactory.store('valid');
      final checker = DatabaseIntegrityChecker(
        storeNames: [''],
        stores: [store],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('whitespace-only store name returns DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase();
      final store = stringMapStoreFactory.store('valid');
      final checker = DatabaseIntegrityChecker(
        storeNames: ['  \t  '],
        stores: [store],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('duplicate store names return DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase();
      final first = stringMapStoreFactory.store('duplicate');
      final second = stringMapStoreFactory.store('duplicate');
      final checker = DatabaseIntegrityChecker(
        storeNames: ['duplicate', 'duplicate'],
        stores: [first, second],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('fewer names than store references returns DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase();
      final checker = DatabaseIntegrityChecker(
        storeNames: ['one'],
        stores: [
          stringMapStoreFactory.store('one'),
          stringMapStoreFactory.store('two'),
        ],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('more names than store references returns DatabaseIntegrityFailure', () async {
      // Given
      final database = await _openDatabase();
      final checker = DatabaseIntegrityChecker(
        storeNames: ['one', 'two'],
        stores: [stringMapStoreFactory.store('one')],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test(
      'store reference whose name differs from its declared name returns '
      'DatabaseIntegrityFailure',
      () async {
        // Given
        final database = await _openDatabase();
        final checker = DatabaseIntegrityChecker(
          storeNames: ['declared'],
          stores: [stringMapStoreFactory.store('actual')],
        );

        // When
        final result = await checker.check(database);

        // Then
        expect(result, isA<DatabaseIntegrityFailure>());
      },
    );

    test('DatabaseException while probing a store returns DatabaseIntegrityFailure', () async {
      // Given
      final store = stringMapStoreFactory.store('unreadable');
      final database = _databaseWithProbeError(
        DatabaseException.closed('store probe failed'),
        store,
      );

      // When
      final result = await DatabaseIntegrityChecker(
        storeNames: ['unreadable'],
        stores: [store],
      ).check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('FileSystemException while probing a store returns DatabaseIntegrityFailure', () async {
      // Given
      final store = stringMapStoreFactory.store('unreadable');
      final database = _databaseWithProbeError(
        const FileSystemException('store probe failed'),
        store,
      );

      // When
      final result = await DatabaseIntegrityChecker(
        storeNames: ['unreadable'],
        stores: [store],
      ).check(database);

      // Then
      expect(result, isA<DatabaseIntegrityFailure>());
    });

    test('failure message identifies the unreadable store', () async {
      // Given
      final store = stringMapStoreFactory.store('unreadable-store');
      final database = _databaseWithProbeError(
        DatabaseException.closed('store probe failed'),
        store,
      );
      const storeName = 'unreadable-store';

      // When
      final result = await DatabaseIntegrityChecker(
        storeNames: [storeName],
        stores: [store],
      ).check(database);

      // Then
      expect(result.failureOrNull?.message, contains(storeName));
    });

    test('a store count of zero is accepted', () async {
      // Given
      final database = await _openDatabase();
      final store = stringMapStoreFactory.store('empty');
      final checker = DatabaseIntegrityChecker(
        storeNames: ['empty'],
        stores: [store],
      );

      // When
      final result = await checker.check(database);

      // Then
      expect(result.isSuccess, isTrue);
      expect(await store.count(database), 0);
    });

    test('the integrity checker never inserts dummy records', () async {
      // Given
      final database = await _openDatabase();
      final store = stringMapStoreFactory.store('empty');
      final checker = DatabaseIntegrityChecker(
        storeNames: ['empty'],
        stores: [store],
      );

      // When
      await checker.check(database);

      // Then
      expect(await store.count(database), 0);
      expect(await store.find(database), isEmpty);
    });

    test('existing data remains unchanged after checking', () async {
      // Given
      final database = await _openDatabase();
      final store = stringMapStoreFactory.store('existing');
      await store.record('record-1').put(database, {'value': 'before'});
      final before = await store.find(database);
      final checker = DatabaseIntegrityChecker(
        storeNames: ['existing'],
        stores: [store],
      );

      // When
      await checker.check(database);

      // Then
      final after = await store.find(database);
      expect(after, hasLength(before.length));
      expect(after.single.key, before.single.key);
      expect(after.single.value, before.single.value);
    });

    test('programmer errors from a store probe are not swallowed', () async {
      // Given
      final errors = [
        ArgumentError('invalid probe'),
        StateError('unexpected probe state'),
      ];

      for (final error in errors) {
        final store = stringMapStoreFactory.store('test');
        final database = _databaseWithProbeError(error, store);

        // When / Then
        await expectLater(
          DatabaseIntegrityChecker(
            storeNames: ['test'],
            stores: [store],
          ).check(database),
          throwsA(same(error)),
        );
      }
    });
  });
}

Future<Database> _openDatabase({int version = DatabaseSchema.version}) async {
  final database = await databaseFactoryMemory.openDatabase(
    'database-integrity-checker-${DateTime.now().microsecondsSinceEpoch}',
    version: version,
  );
  addTearDown(database.close);
  return database;
}

MockIntegrityDatabaseClient _databaseWithProbeError(
  Object error,
  StoreRef<String, Map<String, Object?>> storeRef,
) {
  final database = MockIntegrityDatabaseClient();
  final store = MockIntegrityStore();

  when(() => database.version).thenReturn(DatabaseSchema.version);
  when(() => database.getSembastStore(storeRef)).thenReturn(store);
  when(() => store.txnCount(null, null)).thenThrow(error);

  return database;
}
