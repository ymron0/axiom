import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/development/fixtures/development_fixture_loader.dart';
import 'package:sembast/sembast.dart';

/// Clears all application data and reloads development fixtures.
///
/// This operation is deliberately available only outside release builds.
///
/// Clearing and fixture loading execute in one Sembast transaction. If fixture
/// loading fails, the transaction rolls back and the previous database content
/// remains intact.
///
/// This service bypasses normal domain deletion rules because its purpose is to
/// replace the complete development dataset.
final class ReloadFixturesService {
  /// Creates the development fixture-reset service.
  const ReloadFixturesService({
    required Database database,
    required bool isReleaseMode,
    required DevelopmentFixtureLoader fixtureLoader,
  }) : _database = database, // ignore: prefer_initializing_formals
       _isReleaseMode = isReleaseMode, // ignore: prefer_initializing_formals
       _fixtureLoader = fixtureLoader; // ignore: prefer_initializing_formals

  final Database _database;
  final bool _isReleaseMode;
  final DevelopmentFixtureLoader _fixtureLoader;

  /// Deletes all application-owned records and reloads the fixtures.
  Future<void> call() async {
    if (_isReleaseMode) {
      throw StateError('Fixture reload is not allowed in release builds.');
    }

    await _database.transaction((transaction) async {
      for (final store in SembastStores.all) {
        await store.delete(transaction);
      }

      await _fixtureLoader.load(transaction);
    });
  }
}
