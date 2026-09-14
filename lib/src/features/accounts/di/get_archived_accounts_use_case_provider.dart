import 'package:axiom/src/features/accounts/application/use_cases/get_archived_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_archived_accounts_use_case_provider.g.dart';

/// Provides the use case for retrieving archived accounts.
@riverpod
GetArchivedAccountsUseCase getArchivedAccountsUseCase(Ref ref) {
  return GetArchivedAccountsUseCase(ref.watch(accountRepositoryProvider));
}
