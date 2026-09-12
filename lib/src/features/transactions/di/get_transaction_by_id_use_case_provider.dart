import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_transaction_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving a transaction by identifier.
@riverpod
GetTransactionByIdUseCase getTransactionByIdUseCase(Ref ref) {
  return GetTransactionByIdUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}
