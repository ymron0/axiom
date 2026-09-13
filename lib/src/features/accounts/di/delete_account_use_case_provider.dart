import 'package:axiom/src/features/accounts/application/use_cases/delete_account_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_account_use_case_provider.g.dart';

/// Provides the use case for deleting one account.
@riverpod
DeleteAccountUseCase deleteAccountUseCase(Ref ref) {
  return DeleteAccountUseCase(ref.watch(accountRepositoryProvider));
}
