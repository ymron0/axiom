import 'package:axiom/src/application/services/validate_transaction_jar_balances_service.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_transaction_jar_balances_service_provider.g.dart';

/// Provides configurable transaction jar-balance validation.
@riverpod
ValidateTransactionJarBalancesService validateTransactionJarBalancesService(
  Ref ref,
) {
  return ValidateTransactionJarBalancesService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getTransactionsByJarId: ref.watch(getTransactionsByJarIdUseCaseProvider),
    calculator: const JarBalanceCalculator(),
  );
}
