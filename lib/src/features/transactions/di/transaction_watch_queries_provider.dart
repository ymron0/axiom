import 'package:axiom/src/features/transactions/application/queries/transaction_watch_queries.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_watch_queries_provider.g.dart';

/// Provides reactive transaction queries backed by the configured repository.
@riverpod
TransactionWatchQueries transactionWatchQueries(Ref ref) {
  return TransactionWatchQueries(ref.watch(transactionRepositoryProvider));
}
