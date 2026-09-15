import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sembast_database_provider.g.dart';

/// Provides the application-scoped Sembast database infrastructure.
///
/// Resolving this provider constructs the database wrapper but does not open
/// the database.
///
/// Database opening, integrity validation, shutdown, and recovery remain
/// explicit lifecycle operations rather than dependency-injection side
/// effects.
@Riverpod(keepAlive: true)
SembastDatabase sembastDatabase(Ref ref) {
  return SembastDatabase.io(rootPath: ref.watch(databaseRootPathProvider));
}
