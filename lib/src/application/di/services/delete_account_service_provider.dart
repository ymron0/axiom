import 'package:axiom/src/application/services/delete_account_service.dart';
import 'package:axiom/src/features/accounts/di/delete_account_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_account_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_account_service_provider.g.dart';

/// Provides the service that deletes accounts which have no transactions.
@riverpod
DeleteAccountService deleteAccountService(Ref ref) {
  return DeleteAccountService(
    transactionsExist: ref.watch(
      transactionsExistByAccountIdUseCaseProvider,
    ),
    deleteAccount: ref.watch(deleteAccountUseCaseProvider),
  );
}
