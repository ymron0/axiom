import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Retrieves persisted archived transaction series.
final class GetArchivedTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const GetArchivedTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Returns every archived transaction series.
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>> call() {
    return _repository.getArchived();
  }
}
