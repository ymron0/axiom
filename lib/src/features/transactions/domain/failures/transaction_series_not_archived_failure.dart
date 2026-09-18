import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_not_archived_failure.mapper.dart';

/// Indicates that unarchiving was requested for an active transaction series.
///
/// The referenced series exists and remains persisted; it simply does not have
/// an archival state to remove.
@MappableClass()
final class TransactionSeriesNotArchivedFailure
    extends Failure<TransactionSeriesNotArchivedFailure>
    with TransactionSeriesNotArchivedFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series-not-archived failure with optional operation
  /// context.
  const TransactionSeriesNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesNotArchived';

  @override
  TransactionSeriesNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
