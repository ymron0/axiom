import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

import 'database_migrator.dart';
import 'database_schema.dart';

/// Owns the lifecycle of the application's Sembast database.
///
/// This class is responsible only for database infrastructure:
///
/// - resolving the database file path;
/// - ensuring the database directory exists;
/// - opening the database;
/// - applying schema migrations;
/// - reusing the open database instance;
/// - closing the database.
///
/// Feature repositories must not open or close the database themselves.
final class SembastDatabase {
  final DatabaseFactory _databaseFactory;
  final DatabaseMigrator _migrator;
  final String rootPath;

  Database? _database;
  Future<Database>? _opening;

  /// Creates a database lifecycle manager.
  ///
  /// [databaseFactory] is injectable so tests can supply another Sembast
  /// database factory where appropriate.
  ///
  /// Throws [ArgumentError] when [rootPath] is blank.
  SembastDatabase({
    required DatabaseFactory databaseFactory,
    required this.rootPath,
    DatabaseMigrator migrator = const DatabaseMigrator(),
  }) : _databaseFactory = // ignore: prefer_initializing_formals
           databaseFactory,
       _migrator = // ignore: prefer_initializing_formals
           migrator {
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
    DatabaseMigrator migrator = const DatabaseMigrator(),
  }) {
    return SembastDatabase(
      databaseFactory: databaseFactoryIo,
      rootPath: rootPath,
      migrator: migrator,
    );
  }

  /// Absolute or relative path of the database file.
  String get path => p.join(rootPath, DatabaseSchema.fileName);

  /// Whether this lifecycle manager currently owns an open database.
  bool get isOpen => _database != null;

  /// Returns the database, opening it first when necessary.
  Future<Database> get database => open();

  /// Opens the database.
  ///
  /// Repeated calls return the same database instance until [close] is called.
  ///
  /// Concurrent callers also share the same opening operation rather than
  /// opening the same database multiple times.
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
      _opening = null;
    }
  }

  /// Closes the database if it is open.
  ///
  /// Calling this method while the database is already closed is safe.
  Future<void> close() async {
    final opening = _opening;

    if (opening != null) {
      await opening;
    }

    final database = _database;

    if (database == null) {
      return;
    }

    _database = null;

    await database.close();
  }

  Future<Database> _open() async {
    await Directory(rootPath).create(recursive: true);

    return _databaseFactory.openDatabase(
      path,
      version: DatabaseSchema.version,
      onVersionChanged: _migrator.migrate,
    );
  }
}
