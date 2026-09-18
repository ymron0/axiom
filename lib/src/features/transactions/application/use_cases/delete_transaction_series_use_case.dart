import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_series_use_case.dart';

/// Physically deletes a transaction-series definition.
///
/// Previously generated transactions remain ordinary independent transactions
/// and are not deleted or modified by this operation.
final class DeleteTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const DeleteTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Deletes the series identified by [id].
  ///
  /// The returned snapshot is caller-owned and may later be passed to
  /// [RestoreTransactionSeriesUseCase].
  Future<Result<TransactionSeries, TransactionSeriesFailure>> call(
    TransactionSeriesId id,
  ) {
    return _repository.delete(id);
  }
}
