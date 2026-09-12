import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_version_conflict_failure.mapper.dart';

/// Indicates that an update uses a different transaction class version.
@MappableClass()
final class TransactionVersionConflictFailure
    extends Failure<TransactionVersionConflictFailure>
    with TransactionVersionConflictFailureMappable
    implements TransactionFailure {
  /// Creates a transaction-version-conflict failure with optional details.
  const TransactionVersionConflictFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionVersionConflict';

  @override
  TransactionVersionConflictFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
