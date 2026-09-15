import 'dart:io';

import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/failures/database_integrity_failure.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:sembast/sembast.dart';

/// Performs lightweight structural validation of an opened database.
///
/// The checker verifies infrastructure assumptions required before feature
/// repositories are allowed to use the database.
///
/// It deliberately does not deserialize or validate domain entities.
///
/// ## Checks
///
/// The checker verifies:
///
/// - the opened database version matches [DatabaseSchema.version];
/// - the declared store-name registry is structurally valid;
/// - every declared store reference corresponds to its declared name;
/// - every declared store can be queried.
///
/// ## Empty stores
///
/// An empty store is valid.
///
/// Sembast creates stores lazily, so a new database can legitimately contain
/// no persisted records for most application stores.
///
/// ## Out of scope
///
/// This class does not validate:
///
/// - entity fields;
/// - domain invariants;
/// - foreign-key-like relationships;
/// - transaction/category/jar references;
/// - deleted-record semantics;
/// - unknown historical stores.
///
/// Those concerns belong to repositories, migrations, or dedicated diagnostic
/// tooling.
final class DatabaseIntegrityChecker {
  final int _expectedVersion;
  final List<String> _storeNames;
  final List<StoreRef<String, Map<String, Object?>>> _stores;

  /// Creates an integrity checker.
  ///
  /// Production code should use the defaults.
  ///
  /// [expectedVersion], [storeNames], and [stores] are injectable so individual
  /// validation branches can be tested without modifying global schema
  /// declarations.
  DatabaseIntegrityChecker({
    int expectedVersion = DatabaseSchema.version,
    List<String>? storeNames,
    List<StoreRef<String, Map<String, Object?>>>? stores,
  }) : _expectedVersion = // ignore: prefer_initializing_formals
           expectedVersion,
       _storeNames = List<String>.unmodifiable(
         storeNames ?? SembastStores.allNames,
       ),
       _stores = List<StoreRef<String, Map<String, Object?>>>.unmodifiable(
         stores ?? SembastStores.all,
       );

  /// Checks whether [database] is structurally safe for repository use.
  ///
  /// A successful result contains the same [Database] instance supplied by the
  /// caller.
  ///
  /// Expected storage/readability problems are translated into
  /// [DatabaseIntegrityFailure].
  ///
  /// Programmer errors are intentionally not caught.
  Future<Result<Database, DatabaseIntegrityFailure>> check(
    Database database,
  ) async {
    if (database.version != _expectedVersion) {
      return DatabaseIntegrityFailure(
        message:
            'Opened database schema version ${database.version} does not '
            'match expected version $_expectedVersion.',
      );
    }

    final registryFailure = _validateStoreRegistry();

    if (registryFailure != null) {
      return registryFailure;
    }

    for (final store in _stores) {
      try {
        // A count is a cheap read probe.
        //
        // Zero records is a valid result. The purpose is only to establish
        // that the declared store can be queried.
        await store.count(database);
      } on FileSystemException {
        return DatabaseIntegrityFailure(
          message:
              'Database integrity validation failed while reading '
              'store "${store.name}".',
        );
      } on DatabaseException {
        return DatabaseIntegrityFailure(
          message:
              'Database integrity validation failed while reading '
              'store "${store.name}".',
        );
      }
    }

    return Success<Database>(database);
  }

  /// Validates static consistency between store names and store references.
  DatabaseIntegrityFailure? _validateStoreRegistry() {
    if (_storeNames.length != _stores.length) {
      return const DatabaseIntegrityFailure(
        message:
            'The persistent store-name registry and store-reference registry '
            'have different lengths.',
      );
    }

    if (_storeNames.any((name) => name.trim().isEmpty)) {
      return const DatabaseIntegrityFailure(
        message: 'The persistent store registry contains a blank store name.',
      );
    }

    if (_storeNames.toSet().length != _storeNames.length) {
      return const DatabaseIntegrityFailure(
        message:
            'The persistent store registry contains duplicate store names.',
      );
    }

    for (var index = 0; index < _storeNames.length; index++) {
      final expectedName = _storeNames[index];
      final actualName = _stores[index].name;

      if (actualName != expectedName) {
        return DatabaseIntegrityFailure(
          message:
              'Persistent store registry mismatch at index $index: '
              'expected "$expectedName", found "$actualName".',
        );
      }
    }

    return null;
  }
}
