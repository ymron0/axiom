import 'package:axiom/src/features/custodians/application/queries/custodian_watch_queries.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'custodian_watch_queries_provider.g.dart';

/// Provides reactive custodian queries backed by the configured repository.
@riverpod
CustodianWatchQueries custodianWatchQueries(Ref ref) {
  return CustodianWatchQueries(ref.watch(custodianRepositoryProvider));
}
