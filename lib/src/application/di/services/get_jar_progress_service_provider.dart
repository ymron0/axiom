import 'package:axiom/src/application/services/get_jar_progress_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/jars/domain/services/jar_progress_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_jar_progress_service_provider.g.dart';

/// Provides current jar balance and progress derivation.
@riverpod
GetJarProgressService getJarProgressService(Ref ref) {
  return GetJarProgressService(
    getJarById: ref.watch(getJarByIdUseCaseProvider),
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getTransactionsByJarId: ref.watch(
      getTransactionsByJarIdUseCaseProvider,
    ),
    balanceCalculator: const JarBalanceCalculator(),
    progressCalculator: const JarProgressCalculator(),
    clock: ref.watch(clockProvider),
  );
}