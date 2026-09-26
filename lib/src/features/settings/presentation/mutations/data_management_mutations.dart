import 'package:axiom/src/core/di/application_data_service_providers.dart';
import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/data_management_state.dart';
import '../state/settings_state.dart';

final resetApplicationMutation = Mutation<Result<void, BaseFailure>>(
  label: 'reset-application',
);

/// Executes the atomic reset operation.
///
/// Invalidating the validated database dependency causes repository/use-case
/// dependents to be rebuilt against the now-reset persistence state.
Future<Result<void, BaseFailure>> executeResetApplication(WidgetRef ref) {
  return resetApplicationMutation.run(ref, (transaction) async {
    final service = transaction.get(resetApplicationServiceProvider);

    final result = widenResult(await service());

    if (result.isSuccess) {
      ref
        ..invalidate(validatedDatabaseProvider)
        ..invalidate(applicationDataSummaryProvider)
        ..invalidate(settingsScreenDataProvider);
    }

    return result;
  });
}
