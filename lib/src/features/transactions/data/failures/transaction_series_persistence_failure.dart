import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_persistence_failure.mapper.dart';

/// Indicates that transaction-series persistence failed for an infrastructure
/// or persisted-data reason.
///
/// This failure represents storage-boundary problems such as:
///
/// - malformed persisted transaction-series records;
/// - malformed recurrence definitions;
/// - malformed replacement transaction templates;
/// - Sembast operation failures; and
/// - file-system persistence failures.
///
/// Domain conditions such as a duplicate identity, missing series, or invalid
/// lifecycle transition remain represented by their dedicated failures.
@MappableClass()
final class TransactionSeriesPersistenceFailure
    extends Failure<TransactionSeriesPersistenceFailure>
    with TransactionSeriesPersistenceFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a transaction-series persistence failure.
  const TransactionSeriesPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesPersistence';

  @override
  TransactionSeriesPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
