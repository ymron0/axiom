import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Determines whether persisted transaction series reference an account.
///
/// Both the normal series template and recurrence-exception replacement
/// templates participate in this lookup.
final class TransactionSeriesExistByAccountIdUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const TransactionSeriesExistByAccountIdUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Whether at least one persisted series references [accountId].
  Future<Result<bool, TransactionSeriesFailure>> call(AccountId accountId) {
    return _repository.existsByAccountId(accountId);
  }
}
