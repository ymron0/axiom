import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/application/use_cases/archive_account_use_case.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_account_use_case_provider.g.dart';

/// Provides the use case for archiving one account.
@riverpod
ArchiveAccountUseCase archiveAccountUseCase(Ref ref) {
  return ArchiveAccountUseCase(
    repository: ref.watch(accountRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
