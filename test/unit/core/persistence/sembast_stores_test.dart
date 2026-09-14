@Tags(['core', 'persistence'])
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
      expect(SembastStores.accountsName, 'accounts');
      expect(SembastStores.custodiansName, 'custodians');
      expect(SembastStores.categoriesName, 'categories');
      expect(SembastStores.jarsName, 'jars');
    });
  });
}
