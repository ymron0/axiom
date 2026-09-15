import 'dart:io';

import 'package:axiom/src/core/persistence/database_integrity_checker.dart';
import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

/// Owns isolated persistence resources for one test.
///
/// The environment provides a single place for persistence tests to manage:
///
/// - unique temporary filesystem locations;
/// - in-memory or file-backed Sembast factories;
/// - production [SembastDatabase] instances;
/// - production [DatabaseLifecycleService] instances;
/// - directly opened Sembast databases used to prepare special persisted
///   states;
/// - deterministic teardown of every resource created by the test.
///
/// The actual database root is deliberately nested below [parentDirectory].
/// This allows tests to distinguish between the temporary parent created by
/// the fixture and the database directory created by production persistence
/// code.
///
/// Every environment automatically registers [dispose] through [addTearDown].
/// Tests therefore do not need to manually delete temporary directories.
///
/// This class belongs exclusively to test infrastructure and must never be
/// imported by production code.
final class PersistenceTestEnvironment {
  /// Temporary directory owned by this test environment.
  final Directory parentDirectory;

  /// Root directory supplied to [SembastDatabase].
  ///
  /// Unlike [parentDirectory], this directory is not created when the
  /// environment itself is created. Production database opening is therefore
  /// still responsible for creating it.
  final Directory rootDirectory;

  final DatabaseFactory _databaseFactory;

  final List<Future<void> Function()> _resourceClosers =
      <Future<void> Function()>[];

  bool _disposed = false;

  PersistenceTestEnvironment._(
    this.parentDirectory,
    this.rootDirectory,
    this._databaseFactory,
  );

  /// Creates an isolated environment backed by Sembast's in-memory factory.
  ///
  /// This is the default environment for focused persistence unit tests and
  /// repository tests that do not need to prove physical disk persistence.
  static Future<PersistenceTestEnvironment> createMemory({
    String prefix = 'persistence-memory-test-',
  }) {
    return _create(databaseFactory: databaseFactoryMemory, prefix: prefix);
  }

  /// Creates an isolated environment backed by Sembast's IO factory.
  ///
  /// Use this environment for integration, restart, corruption, migration,
  /// compatibility, and other tests where physical database files matter.
  static Future<PersistenceTestEnvironment> createIo({
    String prefix = 'persistence-io-test-',
  }) {
    return _create(databaseFactory: databaseFactoryIo, prefix: prefix);
  }

  /// Creates an isolated environment using a caller-supplied database factory.
  ///
  /// This is primarily useful for focused unit tests that need a controlled
  /// or mocked [DatabaseFactory] while still requiring proper temporary
  /// filesystem ownership and cleanup.
  static Future<PersistenceTestEnvironment> createWithFactory({
    required DatabaseFactory databaseFactory,
    String prefix = 'persistence-factory-test-',
  }) {
    return _create(databaseFactory: databaseFactory, prefix: prefix);
  }

  /// Whether this environment has already been disposed.
  bool get isDisposed => _disposed;

  /// Path of the physical database file used by this environment.
  String get databasePath =>
      p.join(rootDirectory.path, DatabaseSchema.fileName);

  /// Physical database file used by this environment.
  ///
  /// The returned [File] may not exist yet. Creating the environment alone
  /// does not create the database.
  File get databaseFile => File(databasePath);

  /// Creates a production [SembastDatabase] bound to this environment.
  ///
  /// The database is automatically registered for teardown.
  ///
  /// The returned wrapper starts closed. Call `open()` explicitly or create a
  /// [DatabaseLifecycleService] through [createLifecycle] when lifecycle
  /// validation is part of the scenario.
  SembastDatabase createDatabase({
    DatabaseMigrator migrator = const DatabaseMigrator(),
  }) {
    _ensureActive();

    final database = SembastDatabase(
      databaseFactory: _databaseFactory,
      rootPath: rootDirectory.path,
      migrator: migrator,
    );

    _resourceClosers.add(database.close);

    return database;
  }

  /// Creates a production [DatabaseLifecycleService] for this environment.
  ///
  /// A fresh [SembastDatabase] is created for every call. This is intentional:
  /// integration tests can create a new lifecycle instance against the same
  /// persisted file to simulate an application restart.
  ///
  /// The underlying database wrapper is automatically registered for teardown.
  DatabaseLifecycleService createLifecycle({
    DatabaseMigrator migrator = const DatabaseMigrator(),
    DatabaseIntegrityChecker? integrityChecker,
  }) {
    _ensureActive();

    final database = createDatabase(migrator: migrator);

    return DatabaseLifecycleService(
      database: database,
      integrityChecker: integrityChecker,
    );
  }

  /// Opens the environment database directly through its Sembast factory.
  ///
  /// This deliberately bypasses [SembastDatabase] and
  /// [DatabaseLifecycleService].
  ///
  /// Use it only when a test needs to prepare a persisted state independently
  /// of the production lifecycle, for example:
  ///
  /// - a database created with a newer schema version;
  /// - an existing database that predates application startup;
  /// - a persisted state that will subsequently be migrated;
  /// - raw records required for compatibility or corruption scenarios.
  ///
  /// The returned handle is automatically registered for teardown.
  Future<PersistenceTestDatabaseHandle> openRawDatabase({
    required int version,
  }) async {
    _ensureActive();

    await rootDirectory.create(recursive: true);

    final database = await _databaseFactory.openDatabase(
      databasePath,
      version: version,
      mode: DatabaseMode.create,
    );

    final handle = PersistenceTestDatabaseHandle(database);

    _resourceClosers.add(handle.close);

    return handle;
  }

  /// Closes every tracked persistence resource and deletes the temporary
  /// directory owned by this environment.
  ///
  /// Resources are closed in reverse creation order.
  ///
  /// Cleanup continues after an individual close failure so that one failing
  /// resource cannot prevent the remaining resources or temporary directory
  /// from being cleaned up.
  ///
  /// If cleanup encounters one or more errors, the first error is rethrown
  /// after every cleanup action has been attempted.
  ///
  /// Calling [dispose] more than once is safe.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    Object? firstError;
    StackTrace? firstStackTrace;

    for (final close in _resourceClosers.reversed) {
      try {
        await close();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    _resourceClosers.clear();

    try {
      if (await parentDirectory.exists()) {
        await parentDirectory.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  static Future<PersistenceTestEnvironment> _create({
    required DatabaseFactory databaseFactory,
    required String prefix,
  }) async {
    if (prefix.trim().isEmpty) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'Persistence test directory prefix must not be blank.',
      );
    }

    final parentDirectory = await Directory.systemTemp.createTemp(prefix);

    final environment = PersistenceTestEnvironment._(
      parentDirectory,
      Directory(p.join(parentDirectory.path, 'database')),
      databaseFactory,
    );

    addTearDown(environment.dispose);

    return environment;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError(
        'The persistence test environment has already been disposed.',
      );
    }
  }
}

/// Owns a Sembast [Database] opened directly by
/// [PersistenceTestEnvironment.openRawDatabase].
///
/// Directly opened databases are needed when tests must prepare persistence
/// state without passing through production lifecycle logic.
///
/// [close] is idempotent so tests may close a raw database during the scenario
/// while environment teardown safely closes it again.
final class PersistenceTestDatabaseHandle {
  /// Directly opened Sembast database.
  final Database database;

  bool _closed = false;

  /// Creates a tracked raw database handle.
  PersistenceTestDatabaseHandle(this.database);

  /// Whether this handle has already closed its database.
  bool get isClosed => _closed;

  /// Closes the underlying database once.
  Future<void> close() async {
    if (_closed) {
      return;
    }

    await database.close();

    _closed = true;
  }
}

/// Creates a production [SembastDatabase] suitable for focused unit tests.
///
/// An isolated temporary environment is created automatically and registered
/// for teardown.
///
/// [databaseFactory] defaults to Sembast's in-memory implementation. Supplying
/// another factory is useful when a test needs to control low-level opening
/// behavior.
///
/// Prefer [PersistenceTestEnvironment] directly when the test needs access to
/// filesystem paths, lifecycle creation, raw database preparation, or restart
/// scenarios.
Future<SembastDatabase> createTestSembastDatabase({
  DatabaseFactory? databaseFactory,
  DatabaseMigrator migrator = const DatabaseMigrator(),
}) async {
  final environment = databaseFactory == null
      ? await PersistenceTestEnvironment.createMemory()
      : await PersistenceTestEnvironment.createWithFactory(
          databaseFactory: databaseFactory,
        );

  return environment.createDatabase(migrator: migrator);
}
