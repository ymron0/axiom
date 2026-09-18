import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_already_deleted_failure.mapper.dart';

/// Indicates that an operation requiring an active or archived transaction
/// series received a deleted snapshot instead.
///
/// Deleted series are physically absent from persistence. The deleted
/// snapshot may still be retained by a caller for restoration, but it cannot
/// be created or updated as though it were an active or archived series.
@MappableClass()
final class TransactionSeriesAlreadyDeletedFailure
    extends Failure<TransactionSeriesAlreadyDeletedFailure>
    with TransactionSeriesAlreadyDeletedFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series-already-deleted failure with optional
  /// operation context.
  const TransactionSeriesAlreadyDeletedFailure({String? message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesAlreadyDeleted';

  @override
  TransactionSeriesAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
