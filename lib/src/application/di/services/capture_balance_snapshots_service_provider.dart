import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/capture_balance_snapshots_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/balance_snapshots/di/balance_snapshot_repository_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodians_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_all_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'capture_balance_snapshots_service_provider.g.dart';

/// Provides the scheduling-independent balance-snapshot capture service.
///
/// This provider assembles only application/domain dependencies required to
/// calculate and persist one snapshot set.
///
/// It deliberately contains no scheduler, timer, background-worker, isolate,
/// notification, or platform-lifecycle dependency. A future scheduler may
/// resolve and invoke this service from outside the snapshot feature.
@riverpod
CaptureBalanceSnapshotsService captureBalanceSnapshotsService(Ref ref) {
  return CaptureBalanceSnapshotsService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getAccounts: ref.watch(getAccountsUseCaseProvider),
    getCustodians: ref.watch(getCustodiansUseCaseProvider),
    getJars: ref.watch(getJarsUseCaseProvider),
    getTransactions: ref.watch(getAllTransactionsUseCaseProvider),
    resolveConversionRate: ref.watch(resolveConversionRateServiceProvider),
    assetValuationCalculator: const AssetValuationCalculator(),
    jarBalanceCalculator: const JarBalanceCalculator(),
    snapshotRepository: ref.watch(balanceSnapshotRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
