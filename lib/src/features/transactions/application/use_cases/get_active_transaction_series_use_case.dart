import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Retrieves transaction series eligible for normal future generation.
///
/// This use case filters only by lifecycle state through the repository.
///
/// Recurrence date, count, and amount termination conditions are deliberately
/// not evaluated here. Those conditions belong to occurrence generation.
final class GetActiveTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const GetActiveTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Returns every persisted non-archived transaction series.
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>> call() {
    return _repository.getActive();
  }
}
