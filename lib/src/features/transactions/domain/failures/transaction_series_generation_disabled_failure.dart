import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_series_generation_disabled_failure.mapper.dart';

/// Indicates that planned occurrences cannot be generated from a transaction
/// series because its current state disables generation.
///
/// Paused, archived, and deleted transaction series do not participate in
/// normal future occurrence generation.
///
/// Their recurrence definitions remain available according to their respective
/// persistence and lifecycle semantics.
@MappableClass()
final class TransactionSeriesGenerationDisabledFailure
    extends Failure<TransactionSeriesGenerationDisabledFailure>
    with TransactionSeriesGenerationDisabledFailureMappable
    implements TransactionSeriesFailure {
  /// Creates a generation-disabled failure with optional operation context.
  const TransactionSeriesGenerationDisabledFailure({String? message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionSeriesGenerationDisabled';

  @override
  TransactionSeriesGenerationDisabledFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
