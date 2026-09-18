import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_not_deleted_failure.mapper.dart';

/// Indicates that restoration was requested for a transaction series that is
/// not deleted.
///
/// Restoration requires a caller-retained deleted snapshot. Active and
/// archived series are already present in their usable lifecycle state and
/// cannot be restored through that operation.
@MappableClass()
final class TransactionSeriesNotDeletedFailure
    extends Failure<TransactionSeriesNotDeletedFailure>
    with TransactionSeriesNotDeletedFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series-not-deleted failure with optional operation
  /// context.
  const TransactionSeriesNotDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesNotDeleted';

  @override
  TransactionSeriesNotDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
