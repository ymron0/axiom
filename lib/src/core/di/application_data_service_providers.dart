import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/core/persistence/application_data_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'application_data_service_providers.g.dart';

/// Provides application persistence diagnostics.
@Riverpod(keepAlive: true)
GetApplicationDataSummaryService getApplicationDataSummaryService(Ref ref) {
  return GetApplicationDataSummaryService(
    database: ref.watch(validatedDatabaseProvider),
  );
}

/// Provides the atomic application-reset operation.
@Riverpod(keepAlive: true)
ResetApplicationService resetApplicationService(Ref ref) {
  return ResetApplicationService(
    database: ref.watch(validatedDatabaseProvider),
  );
}
