import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_account_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving an account by identifier.
@riverpod
GetAccountByIdUseCase getAccountByIdUseCase(Ref ref) {
  return GetAccountByIdUseCase(ref.watch(accountRepositoryProvider));
}
