import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/persistence/failures/persistence_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Creates and initializes the root application dependency container.
///
/// The returned container has a successfully opened and validated database.
///
/// The container is disposed automatically when database initialization fails.
Future<Result<ProviderContainer, PersistenceFailure>> bootstrapApplication({
  required List<Override> overrides,
}) async {
  final container = ProviderContainer(overrides: overrides);

  final result = await container.read(databaseLifecycleServiceProvider).open();

  return result.when(
    success: (_) => Success(container),
    failure: (failure) {
      container.dispose();
      return failure;
    },
  );
}