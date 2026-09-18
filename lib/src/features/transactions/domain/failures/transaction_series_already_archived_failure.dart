import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_already_archived_failure.mapper.dart';

/// Indicates that a create or archive operation targeted an already archived
/// transaction series.
///
/// An archived series remains persisted, but it cannot be created as a new
/// active series or archived a second time. This is a domain lifecycle failure,
/// not a persistence failure.
@MappableClass()
final class TransactionSeriesAlreadyArchivedFailure
    extends Failure<TransactionSeriesAlreadyArchivedFailure>
    with TransactionSeriesAlreadyArchivedFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series-already-archived failure with optional
  /// operation context.
  const TransactionSeriesAlreadyArchivedFailure({String? message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesAlreadyArchived';

  @override
  TransactionSeriesAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
