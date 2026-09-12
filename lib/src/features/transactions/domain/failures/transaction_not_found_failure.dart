import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_not_found_failure.mapper.dart';

/// Indicates that an expected transaction does not exist.
@MappableClass()
final class TransactionNotFoundFailure
    extends Failure<TransactionNotFoundFailure>
    with TransactionNotFoundFailureMappable
    implements TransactionFailure {
  /// Creates a transaction-not-found failure with optional details.
  const TransactionNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionNotFound';

  @override
  TransactionNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
