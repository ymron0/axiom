import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';

/// Retrieves persisted ledger entries affecting one account.
class GetLedgerEntriesByAccountIdUseCase {
  /// Creates a use case backed by [repository].
  const GetLedgerEntriesByAccountIdUseCase(this._repository);

  final TransactionRepository _repository;

  /// Returns ledger entries affecting [accountId].
  ///
  /// Ordering and empty-result semantics are defined by
  /// [TransactionRepository.getLedgerEntriesByAccountId].
  Future<Result<List<LedgerEntry>, TransactionFailure>> call(
    AccountId accountId,
  ) {
    return _repository.getLedgerEntriesByAccountId(accountId);
  }
}
