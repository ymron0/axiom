import 'package:axiom/src/application/services/get_jar_balance_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_jar_balance_service_provider.g.dart';

/// Provides the service that derives the current balance of a jar.
///
/// Time is supplied through [clockProvider], keeping the application service
/// deterministic and allowing tests and alternate runtime configurations to
/// replace the clock through DI.
///
/// The stateless [JarBalanceCalculator] is constructed locally.
@riverpod
GetJarBalanceService getJarBalanceService(Ref ref) {
  return GetJarBalanceService(
    getJarById: ref.watch(getJarByIdUseCaseProvider),
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getTransactionsByJarId: ref.watch(getTransactionsByJarIdUseCaseProvider),
    balanceCalculator: const JarBalanceCalculator(),
    clock: ref.watch(clockProvider),
  );
}
