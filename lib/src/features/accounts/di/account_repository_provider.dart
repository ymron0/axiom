import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/accounts/data/repositories/sembast_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_repository_provider.g.dart';

/// Provides the persistent repository used by the accounts feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) {
  return SembastAccountRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
