import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/services/get_custodian_summary_service.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_custodian_summary_service_provider.g.dart';

/// Provides the service that derives custodian balance summaries.
@riverpod
GetCustodianSummaryService getCustodianSummaryService(Ref ref) {
  return GetCustodianSummaryService(
    getCustodianById: ref.watch(getCustodianByIdUseCaseProvider),
    getAccountsByCustodianId: ref.watch(
      getAccountsByCustodianIdUseCaseProvider,
    ),
    getAccountBalance: ref.watch(getAccountBalanceServiceProvider),
  );
}