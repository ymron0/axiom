import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_accounts_use_case_provider.g.dart';

/// Provides the use case for retrieving all accounts.
@riverpod
GetAccountsUseCase getAccountsUseCase(Ref ref) {
  return GetAccountsUseCase(ref.watch(accountRepositoryProvider));
}
