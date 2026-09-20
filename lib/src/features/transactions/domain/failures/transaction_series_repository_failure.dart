import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_repository_failure.mapper.dart';

/// Indicates that a transaction series repository operation could not complete.
@MappableClass()
final class TransactionSeriesRepositoryFailure
    extends Failure<TransactionSeriesRepositoryFailure>
    with TransactionSeriesRepositoryFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction series repository failure with optional details.
  const TransactionSeriesRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesRepository';

  @override
  TransactionSeriesRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
