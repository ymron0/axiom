import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Pauses normal future generation for one transaction series.
///
/// Pausing preserves the recurrence definition, archival state, and already
/// generated transactions.
///
/// Calling the use case for an already-paused series is idempotent.
final class PauseTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const PauseTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Pauses the series identified by [id].
  Future<Result<TransactionSeries, TransactionSeriesFailure>> call(
    TransactionSeriesId id,
  ) async {
    final lookupResult = await _repository.getById(id);

    if (lookupResult case final Failure<TransactionSeriesFailure> failure) {
      return failure;
    }

    final series = lookupResult.valueOrNull;

    if (series == null) {
      return TransactionSeriesNotFoundFailure(
        message:
            'Transaction series ID was not found: '
            '${id.value}',
      );
    }

    final pausedSeries = series.pause(modifiedAt: _clock.nowUtc);

    if (identical(pausedSeries, series)) {
      return Success(series);
    }

    final updateResult = await _repository.update(pausedSeries);

    if (updateResult case final Failure<TransactionSeriesFailure> failure) {
      return failure;
    }

    return Success(pausedSeries);
  }
}
