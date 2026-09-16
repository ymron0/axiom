import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/database_storage_mode_provider.dart';
import 'package:axiom/src/core/persistence/database_storage_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Database storage mode selected at compile time.
///
/// Supported values:
///
/// - `persistent`
/// - `memory`
///
/// When omitted, persistent storage is used.
const String _databaseStorageMode = String.fromEnvironment(
  'DATABASE_STORAGE',
  defaultValue: 'persistent',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databaseOverrides = await _resolveDatabaseOverrides();

  runApp(
    ProviderScope(overrides: [...databaseOverrides], child: const MainApp()),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}

/// Converts the compile-time database configuration into a storage mode.
///
/// Throws [ArgumentError] when:
///
/// - an unsupported value is provided; or
/// - memory storage is requested in a release build.
///
/// Release builds must always use persistent storage.
DatabaseStorageMode _resolveDatabaseStorageMode(String value) {
  final storageMode = switch (value.trim().toLowerCase()) {
    'persistent' => DatabaseStorageMode.persistent,
    'memory' => DatabaseStorageMode.memory,
    _ => throw ArgumentError.value(
      value,
      'DATABASE_STORAGE',
      'Expected "persistent" or "memory".',
    ),
  };

  if (kReleaseMode && storageMode == DatabaseStorageMode.memory) {
    throw StateError(
      'In-memory database storage is not allowed in release builds.',
    );
  }

  return storageMode;
}

/// Resolves database provider overrides for the configured storage mode.
///
/// Persistent storage uses the application documents directory; memory storage
/// does not override the database root path.
Future<List<Override>> _resolveDatabaseOverrides() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();

  final storageMode = _resolveDatabaseStorageMode(_databaseStorageMode);

  final persistentDatabaseOverrides = [
    databaseStorageModeProvider.overrideWithValue(
      DatabaseStorageMode.persistent,
    ),
    databaseRootPathProvider.overrideWithValue(documentsDirectory.path),
  ];

  final memoryDatabaseOverrides = [
    databaseStorageModeProvider.overrideWithValue(DatabaseStorageMode.memory),
  ];

  return switch (storageMode) {
    DatabaseStorageMode.memory => memoryDatabaseOverrides,
    _ => persistentDatabaseOverrides,
  };
}
