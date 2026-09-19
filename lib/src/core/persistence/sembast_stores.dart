import 'package:sembast/sembast.dart';

/// Central registry of Sembast stores used by the application.
///
/// Domain identifiers are represented as strings in persistence, so
/// string-keyed map stores are used for persisted domain entities.
///
/// Feature repositories must use these store references rather than declaring
/// their own store names.
///
/// Store names are part of the persistent database schema. Once a store name
/// has been released, it must not be renamed without a database migration.
abstract final class SembastStores {
  static const String assetsName = 'assets';
  static const String settingsName = 'settings';
  static const String ratesName = 'rates';
  static const String merchantsName = 'merchants';
  static const String transactionsName = 'transactions';
  static const String transactionSeriesName = 'transactionSeries';
  static const String accountsName = 'accounts';
  static const String custodiansName = 'custodians';
  static const String categoriesName = 'categories';
  static const String jarsName = 'jars';
  static const String tagsName = 'tags';

  /// Names of every application-owned Sembast store.
  ///
  /// Keep this list synchronized with the store references declared below.
  static const List<String> allNames = <String>[
    assetsName,
    settingsName,
    ratesName,
    merchantsName,
    transactionsName,
    transactionSeriesName,
    accountsName,
    custodiansName,
    categoriesName,
    jarsName,
    tagsName,
  ];

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

  static final StoreRef<String, Map<String, Object?>> transactionSeries =
      stringMapStoreFactory.store(transactionSeriesName);

  static final StoreRef<String, Map<String, Object?>> accounts =
      stringMapStoreFactory.store(accountsName);

  static final StoreRef<String, Map<String, Object?>> custodians =
      stringMapStoreFactory.store(custodiansName);

  static final StoreRef<String, Map<String, Object?>> categories =
      stringMapStoreFactory.store(categoriesName);

  static final StoreRef<String, Map<String, Object?>> jars =
      stringMapStoreFactory.store(jarsName);

  static final StoreRef<String, Map<String, Object?>> tags =
      stringMapStoreFactory.store(tagsName);

  /// References to every application-owned Sembast store.
  ///
  /// This is primarily intended for database-level infrastructure such as
  /// schema validation, diagnostics, and migrations. Feature repositories
  /// should depend on their specific store reference instead.
  static final List<StoreRef<String, Map<String, Object?>>> all =
      List<StoreRef<String, Map<String, Object?>>>.unmodifiable(
        <StoreRef<String, Map<String, Object?>>>[
          assets,
          settings,
          rates,
          merchants,
          transactions,
          transactionSeries,
          accounts,
          custodians,
          categories,
          jars,
          tags,
        ],
      );
}
