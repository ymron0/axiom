import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_repository_provider.g.dart';

/// Provides the repository used by the transactions feature.
@riverpod
TransactionRepository transactionRepository(Ref ref) {
  return InMemoryTransactionRepositoryImpl();
}
