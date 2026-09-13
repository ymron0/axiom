import 'package:axiom/src/features/accounts/application/use_cases/update_account_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_account_use_case_provider.g.dart';

/// Provides the use case for updating one account.
@riverpod
UpdateAccountUseCase updateAccountUseCase(Ref ref) {
  return UpdateAccountUseCase(ref.watch(accountRepositoryProvider));
}
