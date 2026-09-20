import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_repository_failure.mapper.dart';

/// Indicates that a transaction repository operation could not complete.
@MappableClass()
final class TransactionRepositoryFailure
    extends Failure<TransactionRepositoryFailure>
    with TransactionRepositoryFailureMappable
    implements TransactionFailure {
  /// Creates a transaction repository failure with optional details.
  const TransactionRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.repository';

  @override
  TransactionRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
