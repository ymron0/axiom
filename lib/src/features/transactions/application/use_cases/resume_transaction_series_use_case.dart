import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_archived_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Resumes normal future generation for one paused transaction series.
///
/// Archived series cannot be resumed directly. They must first be unarchived.
///
/// Unarchiving deliberately does not call this use case or otherwise clear
/// pause state.
///
/// Calling the use case for an already-unpaused series is idempotent.
final class ResumeTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const ResumeTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Resumes the series identified by [id].
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

    if (series.isArchived) {
      return TransactionSeriesAlreadyArchivedFailure(
        message:
            'Archived transaction series cannot be resumed: '
            '${id.value}',
      );
    }

    final resumedSeries = series.resume(modifiedAt: _clock.nowUtc);

    if (identical(resumedSeries, series)) {
      return Success(series);
    }

    final updateResult = await _repository.update(resumedSeries);

    if (updateResult case final Failure<TransactionSeriesFailure> failure) {
      return failure;
    }

    return Success(resumedSeries);
  }
}
