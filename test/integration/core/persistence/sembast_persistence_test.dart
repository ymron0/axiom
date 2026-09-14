@Tags(['core', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:sembast/sembast.dart';
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
  });
}
