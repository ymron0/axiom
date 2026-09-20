@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:test/test.dart';

void main() {
  group('SembastStores', () {
    test('uses stable store names', () {
      expect(SembastStores.assetsName, 'assets');
      expect(SembastStores.settingsName, 'settings');
      expect(SembastStores.ratesName, 'rates');
      expect(SembastStores.merchantsName, 'merchants');
      expect(SembastStores.transactionsName, 'transactions');
      expect(SembastStores.transactionSeriesName, 'transactionSeries');
      expect(SembastStores.accountsName, 'accounts');
      expect(SembastStores.custodiansName, 'custodians');
      expect(SembastStores.categoriesName, 'categories');
      expect(SembastStores.jarsName, 'jars');
      expect(SembastStores.tagsName, 'tags');
      expect(SembastStores.balanceSnapshotsName, 'balanceSnapshots');
    });

    test('registers every current application store', () {
      expect(SembastStores.allNames, <String>[
        'assets',
        'settings',
        'rates',
        'merchants',
        'transactions',
        'transactionSeries',
        'accounts',
        'custodians',
        'categories',
        'jars',
        'tags',
        'balanceSnapshots',
      ]);
    });

    test('store names are unique', () {
      final uniqueNames = SembastStores.allNames.toSet();

      expect(uniqueNames.length, SembastStores.allNames.length);
    });

    test('store references use their declared names', () {
      expect(SembastStores.assets.name, SembastStores.assetsName);

      expect(SembastStores.settings.name, SembastStores.settingsName);

      expect(SembastStores.rates.name, SembastStores.ratesName);

      expect(SembastStores.merchants.name, SembastStores.merchantsName);

      expect(SembastStores.transactions.name, SembastStores.transactionsName);

      expect(
        SembastStores.transactionSeries.name,
        SembastStores.transactionSeriesName,
      );

      expect(SembastStores.accounts.name, SembastStores.accountsName);

      expect(SembastStores.custodians.name, SembastStores.custodiansName);

      expect(SembastStores.categories.name, SembastStores.categoriesName);

      expect(SembastStores.jars.name, SembastStores.jarsName);

      expect(SembastStores.tags.name, SembastStores.tagsName);

      expect(
        SembastStores.balanceSnapshots.name,
        SembastStores.balanceSnapshotsName,
      );
    });

    test('all store references correspond to all declared names', () {
      final registeredNames = SembastStores.all
          .map((store) => store.name)
          .toList(growable: false);

      expect(registeredNames, SembastStores.allNames);
    });

    test('all store registry cannot be modified', () {
      expect(
        () => SembastStores.all.add(SembastStores.assets),
        throwsUnsupportedError,
      );
    });
  });
}
