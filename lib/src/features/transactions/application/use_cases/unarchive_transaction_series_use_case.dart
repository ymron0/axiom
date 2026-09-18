import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Reactivates an archived transaction series.
///
/// Reactivation affects only future generation eligibility. It does not create,
/// restore, or alter ordinary transactions.
final class UnarchiveTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const UnarchiveTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Removes archival state from the series identified by [id].
  Future<Result<TransactionSeries, TransactionSeriesFailure>> call(
    TransactionSeriesId id,
  ) {
    return _repository.unarchive(id, _clock.nowUtc);
  }
}
