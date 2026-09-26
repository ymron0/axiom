import 'package:axiom/src/core/di/application_data_service_providers.dart';
import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:axiom/src/features/settings/presentation/state/data_management_state.dart';
import 'package:axiom/src/features/settings/presentation/state/settings_state.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final resetApplicationMutation = Mutation<Result<void, BaseFailure>>(
  label: 'reset-application',
);

/// Executes the atomic reset operation.
///
/// The onboarding completion record is reset together with user financial
/// state. Refreshing [firstRunDetectionProvider] therefore returns the root
/// presentation to onboarding automatically.
Future<Result<void, BaseFailure>> executeResetApplication(WidgetRef ref) {
  return resetApplicationMutation.run(ref, (transaction) async {
    final service = transaction.get(resetApplicationServiceProvider);

    final result = widenResult(await service());

    if (result.isSuccess) {
      ref
        ..invalidate(validatedDatabaseProvider)
        ..invalidate(applicationDataSummaryProvider)
        ..invalidate(settingsScreenDataProvider)
        ..invalidate(onboardingSetupDataProvider)
        ..invalidate(firstRunDetectionProvider);
    }

    return result;
  });
}
