import 'package:axiom/src/features/accounts/application/queries/account_watch_queries.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_watch_queries_provider.g.dart';

/// Provides reactive account queries backed by the configured repository.
@riverpod
AccountWatchQueries accountWatchQueries(Ref ref) {
  return AccountWatchQueries(ref.watch(accountRepositoryProvider));
}
