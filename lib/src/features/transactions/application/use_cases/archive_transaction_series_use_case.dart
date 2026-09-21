import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Archives a persisted transaction series.
///
/// Archiving automatically pauses the series and disables normal future
/// occurrence generation.
///
/// The recurrence definition and transactions already generated from the series
/// remain untouched.
final class ArchiveTransactionSeriesUseCase {
  final TransactionSeriesRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const ArchiveTransactionSeriesUseCase({
    required TransactionSeriesRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Archives the series identified by [id].
  Future<Result<TransactionSeries, TransactionSeriesFailure>> call(
    TransactionSeriesId id,
  ) {
    return _repository.archive(id, _clock.nowUtc);
  }
}
