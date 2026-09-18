import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Restores a caller-retained physically deleted transaction-series snapshot.
///
/// Restoration affects only the recurrence definition. Ordinary transactions
/// are neither restored nor modified.
///
/// The repository validates that [series] represents a deleted snapshot and
/// that its identity is available for restoration.
final class RestoreTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const RestoreTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Restores [series] to persistence.
  ///
  /// Its original archival state is preserved by the repository.
  Future<Result<void, TransactionSeriesFailure>> call(
    TransactionSeries series,
  ) {
    return _repository.restore(series);
  }
}
