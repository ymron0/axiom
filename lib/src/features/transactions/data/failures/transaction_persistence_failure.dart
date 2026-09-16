import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_persistence_failure.mapper.dart';

/// Indicates that transaction persistence failed for an infrastructure reason.
///
/// This failure represents failures at the storage boundary, including:
///
/// - malformed persisted transaction data;
/// - Sembast operation failures; and
/// - file-system persistence failures.
///
/// Domain-level conditions such as duplicate transaction identifiers, missing
/// transactions, deleted snapshots, and entity-version conflicts continue to
/// use their existing transaction-specific failures.
@MappableClass()
final class TransactionPersistenceFailure
    extends Failure<TransactionPersistenceFailure>
    with TransactionPersistenceFailureMappable
    implements TransactionFailure {
  /// Creates a transaction persistence failure with optional details.
  const TransactionPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.persistence';

  @override
  TransactionPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
