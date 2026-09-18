import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_already_exists_failure.mapper.dart';

/// Indicates that a transaction-series identifier is already persisted.
///
/// This failure is returned when creation or restoration would overwrite an
/// existing series. The existing persisted series is left unchanged.
@MappableClass()
final class TransactionSeriesAlreadyExistsFailure
    extends Failure<TransactionSeriesAlreadyExistsFailure>
    with TransactionSeriesAlreadyExistsFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series-already-exists failure with optional
  /// operation context.
  const TransactionSeriesAlreadyExistsFailure({String? message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesAlreadyExists';

  @override
  TransactionSeriesAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
