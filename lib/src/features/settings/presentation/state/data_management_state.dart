import 'package:axiom/src/core/di/application_data_service_providers.dart';
import 'package:axiom/src/core/persistence/application_data_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'data_management_state.g.dart';

/// Loads current application persistence counts.
@riverpod
Future<Result<ApplicationDataSummary, ApplicationDataFailure>>
applicationDataSummary(Ref ref) {
  return ref.watch(getApplicationDataSummaryServiceProvider)();
}
