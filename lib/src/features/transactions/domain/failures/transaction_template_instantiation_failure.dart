import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_template_instantiation_failure.mapper.dart';

/// Indicates that a transaction template could not be materialized as a valid
/// transaction.
///
/// Transaction aggregate invariants remain owned by `Transaction`. Templates do
/// not duplicate those rules. When materialization violates one of those
/// invariants, the invariant error is translated into this expected typed
/// failure.
@MappableClass()
final class TransactionTemplateInstantiationFailure
    extends Failure<TransactionTemplateInstantiationFailure>
    with TransactionTemplateInstantiationFailureMappable
    implements TransactionFailure {
  /// Creates a template-instantiation failure with optional details.
  const TransactionTemplateInstantiationFailure({String? message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionTemplateInstantiation';

  @override
  TransactionTemplateInstantiationFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
