import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

import 'database_migrator.dart';
import 'database_schema.dart';

/// Owns the low-level lifecycle of the application's Sembast database.
///
/// This class is responsible only for Sembast infrastructure:
///
/// - resolving the database file path;
/// - ensuring the database directory exists;
/// - opening the database;
/// - invoking schema migration when required;
/// - sharing one in-flight opening operation;
/// - reusing the currently open database;
/// - closing the database.
///
/// Higher-level policy such as integrity validation, typed failure translation,
/// and recovery belongs to `DatabaseLifecycleService`.
///
/// Feature repositories must never open or close the database themselves.
///
/// ## Safety
///
/// The database is explicitly opened with [DatabaseMode.create] rather than
/// Sembast's default `neverFails` mode.
///
/// `create` means:
///
/// - create the database when it does not exist;
/// - open an existing database when it does exist;
/// - propagate corruption/opening errors rather than automatically replacing
///   the database.
///
/// Persisted financial data must never be silently discarded as an automatic
/// recovery strategy.
final class SembastDatabase {
  final DatabaseFactory _databaseFactory;
  final DatabaseMigrator _migrator;
  final String rootPath;

  Database? _database;
  Future<Database>? _opening;

  /// Creates a database lifecycle manager.
  ///
  /// [databaseFactory] is injectable so tests can use an in-memory factory or
  /// a controlled test double.
  ///
  /// [migrator] can be replaced by tests that need custom schema histories.
  /// Production code uses the migration registry associated with the current
  /// `DatabaseSchema.version`.
  ///
  /// Throws [ArgumentError] when [rootPath] is blank.
  SembastDatabase({
    required DatabaseFactory databaseFactory,
    required this.rootPath,
    DatabaseMigrator? migrator,
  }) : _databaseFactory = // ignore: prefer_initializing_formals
           databaseFactory,
       _migrator = migrator ?? DatabaseMigrator() {
    if (rootPath.trim().isEmpty) {
      throw ArgumentError.value(
        rootPath,
        'rootPath',
        'Database root path must not be blank.',
      );
    }
  }

  /// Creates a file-backed Sembast database using the standard IO factory.
  ///
  /// This is the normal constructor for production Dart VM and Flutter usage.
  factory SembastDatabase.io({
    required String rootPath,
    DatabaseMigrator? migrator,
  }) {
    return SembastDatabase(
      databaseFactory: databaseFactoryIo,
      rootPath: rootPath,
      migrator: migrator,
    );
  }

  /// Absolute or relative path of the database file.
  String get path => p.join(rootPath, DatabaseSchema.fileName);

  /// Whether this wrapper currently owns an open database.
  bool get isOpen => _database != null;

  /// Returns the database, opening it first when necessary.
  Future<Database> get database => open();

  /// Opens the database.
  ///
  /// Repeated calls return the same database instance until [close] is called.
  ///
  /// Concurrent callers share the same in-flight open operation rather than
  /// attempting to open the same database multiple times.
  Future<Database> open() async {
    final currentDatabase = _database;

    if (currentDatabase != null) {
      return currentDatabase;
    }

    final currentOpening = _opening;

    if (currentOpening != null) {
      return currentOpening;
    }

    final opening = _open();

    _opening = opening;

    try {
      final database = await opening;

      _database = database;

      return database;
    } finally {
      // Always clear the in-flight operation, including when opening fails.
      //
      // This allows a later recovery attempt to call open again.
      _opening = null;
    }
  }

  /// Closes the database if it is open.
  ///
  /// Calling this method while the database is already closed is safe.
  ///
  /// If an opening operation is currently running, closing waits for that
  /// operation to finish before continuing.
  Future<void> close() async {
    final opening = _opening;

    if (opening != null) {
      await opening;
    }

    final database = _database;

    if (database == null) {
      return;
    }

    // Clear ownership before awaiting the actual close.
    //
    // Even if Sembast reports an operational close error, this wrapper must not
    // continue exposing the database as a healthy active instance.
    _database = null;

    await database.close();
  }

  /// Performs the actual Sembast open operation.
  Future<Database> _open() async {
    await Directory(rootPath).create(recursive: true);

    return _databaseFactory.openDatabase(
      path,
      version: DatabaseSchema.version,
      onVersionChanged: _migrator.migrate,

      // Do not use Sembast's default `DatabaseMode.neverFails`.
      //
      // `neverFails` may delete a corrupted database. `create` still creates a
      // missing database but allows corruption/open errors to propagate.
      mode: DatabaseMode.create,
    );
  }
}