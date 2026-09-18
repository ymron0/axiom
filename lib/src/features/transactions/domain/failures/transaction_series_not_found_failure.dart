import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_not_found_failure.mapper.dart';

/// Indicates that the requested transaction-series identifier is not persisted.
///
/// Because deletion is physical, a deleted series is also absent from general
/// repository lookups and produces this failure when addressed by identifier.
@MappableClass()
final class TransactionSeriesNotFoundFailure
    extends Failure<TransactionSeriesNotFoundFailure>
    with TransactionSeriesNotFoundFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series-not-found failure with optional operation
  /// context.
  const TransactionSeriesNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesNotFound';

  @override
  TransactionSeriesNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
