@Tags(['integration', 'core', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart';

void main() {
  group('Sembast persistence', () {
    test('database directory is created automatically', () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'persistence-foundation-',
      );

      final nestedDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}nested',
      );

      final database = SembastDatabase.io(rootPath: nestedDirectory.path);

      try {
        expect(await nestedDirectory.exists(), isFalse);

        await database.open();

        expect(await nestedDirectory.exists(), isTrue);
      } finally {
        await database.close();

        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      }
    });

    test('data survives database close and reopen', () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'persistence-reopen-',
      );

      final firstDatabase = SembastDatabase.io(
        rootPath: temporaryDirectory.path,
      );

      try {
        final openedDatabase = await firstDatabase.open();

        await SembastStores.settings.record('persistence-test').put(
          openedDatabase,
          <String, Object?>{'value': 'survives-reopen'},
        );

        await firstDatabase.close();

        final secondDatabase = SembastDatabase.io(
          rootPath: temporaryDirectory.path,
        );

        try {
          final reopenedDatabase = await secondDatabase.open();

          final persistedValue = await SembastStores.settings
              .record('persistence-test')
              .get(reopenedDatabase);

          expect(persistedValue, <String, Object?>{'value': 'survives-reopen'});
        } finally {
          await secondDatabase.close();
        }
      } finally {
        await firstDatabase.close();

        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      }
    });

    test(
      'corrupt file-backed database fails without deleting or replacing the original',
      () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'persistence-corrupt-open-',
        );
        final database = SembastDatabase(
          databaseFactory: databaseFactoryIo,
          rootPath: temporaryDirectory.path,
        );
        final originalBytes = <int>[0, 1, 2, 3];
        final databaseFile = File(database.path);

        try {
          await databaseFile.writeAsBytes(originalBytes, flush: true);

          await expectLater(database.open(), throwsA(anything));

          expect(await databaseFile.readAsBytes(), originalBytes);
        } finally {
          await database.close();

          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        }
      },
    );

    test(
      'failed corrupt file-backed open leaves the original file present',
      () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'persistence-corrupt-presence-',
        );
        final database = SembastDatabase(
          databaseFactory: databaseFactoryIo,
          rootPath: temporaryDirectory.path,
        );
        final databaseFile = File(database.path);

        try {
          await databaseFile.writeAsString('corrupt database', flush: true);

          await expectLater(database.open(), throwsA(anything));

          expect(await databaseFile.exists(), isTrue);
        } finally {
          await database.close();

          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        }
      },
    );
  });
}
