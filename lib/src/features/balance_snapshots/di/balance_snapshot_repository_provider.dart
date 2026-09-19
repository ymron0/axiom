import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/balance_snapshots/data/repositories/sembast_balance_snapshot_repository_impl.dart';
import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'balance_snapshot_repository_provider.g.dart';

/// Provides the persistent repository used by the balance-snapshot feature.
///
/// Database lifecycle ownership remains outside the feature. The database must
/// already have completed the validated persistence lifecycle before this
/// provider is resolved.
///
/// Scheduling, background execution, platform lifecycle, and notification
/// concerns deliberately do not belong to this provider.
@Riverpod(keepAlive: true)
BalanceSnapshotRepository balanceSnapshotRepository(Ref ref) {
  return SembastBalanceSnapshotRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
