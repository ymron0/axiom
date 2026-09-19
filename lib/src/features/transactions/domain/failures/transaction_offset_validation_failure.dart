import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_offset_validation_failure.mapper.dart';

/// Indicates that a transaction offset violates relationship invariants.
///
/// This failure describes invalid relationships between an original transaction
/// and a transaction that economically offsets it.
///
/// Examples include:
///
/// - attempting to offset a planned transaction;
/// - attempting to offset another offset transaction;
/// - using the wrong transaction direction;
/// - using a different transaction currency;
/// - referencing the wrong original transaction; or
/// - using allocation targets that do not exist on the original transaction.
@MappableClass()
final class TransactionOffsetValidationFailure
    extends Failure<TransactionOffsetValidationFailure>
    with TransactionOffsetValidationFailureMappable
    implements TransactionFailure {
  /// Creates an offset-validation failure with optional diagnostic details.
  const TransactionOffsetValidationFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionOffsetValidation';

  @override
  TransactionOffsetValidationFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
