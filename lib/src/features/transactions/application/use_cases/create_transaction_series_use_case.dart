import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Creates and persists one active transaction series.
///
/// This use case persists only the recurrence definition represented by
/// [TransactionSeries].
///
/// It does not create ordinary transactions or materialize recurrence
/// occurrences. Occurrence generation belongs to the dedicated generation
/// workflow.
final class CreateTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const CreateTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Persists [series].
  ///
  /// Repository failures are returned unchanged.
  Future<Result<void, TransactionSeriesFailure>> call(
    TransactionSeries series,
  ) {
    return _repository.create(series);
  }
}
