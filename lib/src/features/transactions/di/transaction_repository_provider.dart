import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/di/transaction_offset_policy_provider.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_repository_provider.g.dart';

/// Provides the persistent repository used by the transactions feature.
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) {
  return SembastTransactionRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
    offsetPolicy: ref.watch(transactionOffsetPolicyProvider),
  );
}
