import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Retrieves every persisted transaction series.
///
/// Both active and archived series are returned.
final class GetTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const GetTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Returns every persisted transaction series.
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>> call() {
    return _repository.getAll();
  }
}
