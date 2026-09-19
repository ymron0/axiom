import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_offset.mapper.dart';

/// Identifies the transaction that an offset transaction economically reduces.
///
/// This value object stores relationship metadata only. The referenced original
/// transaction, transaction kinds, amounts, timing, and cumulative capacity are
/// validated by the offset policy and transaction repository.
@MappableClass()
final class TransactionOffset with TransactionOffsetMappable {
  /// The original transaction receiving the economic offset.
  final TransactionId originalTransactionId;

  /// The reason the offset reduces the original transaction.
  final TransactionOffsetKind kind;

  /// Creates an offset relationship descriptor.
  const TransactionOffset({
    required this.originalTransactionId,
    required this.kind,
  });
}
