import 'package:axiom/src/application/services/historical_balance_query_service.dart';
import 'package:axiom/src/features/balance_snapshots/di/balance_snapshot_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'historical_balance_query_service_provider.g.dart';

/// Provides historical balance queries backed by persisted daily snapshots.
///
/// The application service remains storage-independent and depends only on the
/// balance-snapshot repository contract.
@riverpod
HistoricalBalanceQueryService historicalBalanceQueryService(Ref ref) {
  return HistoricalBalanceQueryService(
    ref.watch(balanceSnapshotRepositoryProvider),
  );
}
