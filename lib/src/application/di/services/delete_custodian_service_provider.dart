import 'package:axiom/src/application/services/delete_custodian_service.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/delete_custodian_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_custodian_service_provider.g.dart';

/// Provides the service that deletes custodians which have no accounts.
@riverpod
DeleteCustodianService deleteCustodianService(Ref ref) {
  return DeleteCustodianService(
    getAccounts: ref.watch(getAccountsByCustodianIdUseCaseProvider),
    deleteCustodian: ref.watch(deleteCustodianUseCaseProvider),
  );
}
