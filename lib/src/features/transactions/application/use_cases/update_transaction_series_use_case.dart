import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Replaces one persisted transaction-series snapshot.
///
/// Updating the recurrence definition does not modify any ordinary transaction
/// that may previously have been generated from the series.
final class UpdateTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const UpdateTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Persists the supplied [series] snapshot.
  Future<Result<void, TransactionSeriesFailure>> call(
    TransactionSeries series,
  ) {
    return _repository.update(series);
  }
}
