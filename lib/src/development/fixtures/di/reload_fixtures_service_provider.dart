import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/development/fixtures/development_fixture_loader.dart';
import 'package:axiom/src/development/fixtures/reload_fixtures_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reload_fixtures_service_provider.g.dart';

/// Provides the destructive development fixture-reset operation.
@Riverpod(keepAlive: true)
ReloadFixturesService reloadFixturesService(Ref ref) {
  return ReloadFixturesService(
    database: ref.watch(validatedDatabaseProvider),
    isReleaseMode: kReleaseMode,
    fixtureLoader: DevelopmentFixtureLoader(),
  );
}
