import 'package:axiom/src/features/transactions/application/use_cases/get_ledger_entries_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_ledger_entries_by_account_id_use_case_provider.g.dart';

/// Provides the use case for retrieving ledger entries by account identifier.
@riverpod
GetLedgerEntriesByAccountIdUseCase getLedgerEntriesByAccountIdUseCase(Ref ref) {
  return GetLedgerEntriesByAccountIdUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}
