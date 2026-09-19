import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_offset_exceeds_available_amount_failure.mapper.dart';

/// Indicates that cumulative transaction offsets exceed available value.
///
/// Refunds, reimbursements, cashback, and future offset kinds all consume the
/// same remaining economic value of the original transaction.
///
/// For example, a CHF 100 expense that already has CHF 80 of offsets cannot
/// receive another CHF 30 offset.
@MappableClass()
final class TransactionOffsetExceedsAvailableAmountFailure
    extends Failure<TransactionOffsetExceedsAvailableAmountFailure>
    with TransactionOffsetExceedsAvailableAmountFailureMappable
    implements TransactionFailure {
  /// Creates an over-offset failure with optional diagnostic details.
  const TransactionOffsetExceedsAvailableAmountFailure({String? message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'transactions.transactionOffsetExceedsAvailableAmount';

  @override
  TransactionOffsetExceedsAvailableAmountFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
