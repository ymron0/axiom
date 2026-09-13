import 'package:axiom/src/features/accounts/application/use_cases/restore_account_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_account_use_case_provider.g.dart';

/// Provides the use case for restoring one account.
@riverpod
RestoreAccountUseCase restoreAccountUseCase(Ref ref) {
  return RestoreAccountUseCase(ref.watch(accountRepositoryProvider));
}
