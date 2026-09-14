import 'package:sembast/sembast.dart';

/// Central registry of Sembast stores used by the application.
///
/// Domain identifiers are represented as strings in persistence, so
/// string-keyed map stores are used for persisted domain entities.
///
/// Feature repositories should use these store references rather than
/// declaring their own store names.
abstract final class SembastStores {
  static const String assetsName = 'assets';
  static const String settingsName = 'settings';
  static const String ratesName = 'rates';
  static const String merchantsName = 'merchants';
  static const String transactionsName = 'transactions';
  static const String accountsName = 'accounts';
  static const String custodiansName = 'custodians';
  static const String categoriesName = 'categories';
  static const String jarsName = 'jars';

  static final StoreRef<String, Map<String, Object?>> assets =
      stringMapStoreFactory.store(assetsName);

  static final StoreRef<String, Map<String, Object?>> settings =
      stringMapStoreFactory.store(settingsName);

  static final StoreRef<String, Map<String, Object?>> rates =
      stringMapStoreFactory.store(ratesName);

  static final StoreRef<String, Map<String, Object?>> merchants =
      stringMapStoreFactory.store(merchantsName);

  static final StoreRef<String, Map<String, Object?>> transactions =
      stringMapStoreFactory.store(transactionsName);

  static final StoreRef<String, Map<String, Object?>> accounts =
      stringMapStoreFactory.store(accountsName);

  static final StoreRef<String, Map<String, Object?>> custodians =
      stringMapStoreFactory.store(custodiansName);

  static final StoreRef<String, Map<String, Object?>> categories =
      stringMapStoreFactory.store(categoriesName);

  static final StoreRef<String, Map<String, Object?>> jars =
      stringMapStoreFactory.store(jarsName);
}
