import 'package:axiom/src/features/accounts/data/repositories/in_memory_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_repository_provider.g.dart';

/// Provides the repository used by the accounts feature.
@riverpod
AccountRepository accountRepository(Ref ref) {
  return InMemoryAccountRepositoryImpl();
}
