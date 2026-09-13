import 'package:axiom/src/features/accounts/application/use_cases/search_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_accounts_use_case_provider.g.dart';

/// Provides the use case for searching accounts.
@riverpod
SearchAccountsUseCase searchAccountsUseCase(Ref ref) {
  return SearchAccountsUseCase(ref.watch(accountRepositoryProvider));
}
