import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';

/// Input required to create an offset of an existing transaction.
///
/// Transaction identity, audit metadata, transaction kind, lifecycle state, and
/// the complete [TransactionOffset] relationship are derived by the application
/// service.
///
/// The command describes the new financial movement itself.
///
/// For example, when a partner reimburses part of a restaurant expense,
/// [merchantId] identifies the partner rather than the restaurant.
final class CreateTransactionOffsetCommand {
  /// Original transaction whose economic value is being reduced.
  final TransactionId originalTransactionId;

  /// Why the new transaction offsets the original.
  final TransactionOffsetKind offsetKind;

  /// Merchant or counterparty associated with the new financial movement.
  final MerchantId merchantId;

  /// Effective time of the new financial movement.
  final DateTime effectiveAt;

  /// Optional description.
  final String? description;

  /// Optional note.
  final String? note;

  /// Allocations belonging to the offset transaction.
  final List<TransactionSplit> splits;

  /// Account impacts belonging to the offset transaction.
  final List<LedgerEntry> ledgerEntries;

  /// Creates a transaction-offset command.
  CreateTransactionOffsetCommand({
    required this.originalTransactionId,
    required this.offsetKind,
    required this.merchantId,
    required this.effectiveAt,
    this.description,
    this.note,
    required List<TransactionSplit> splits,
    required List<LedgerEntry> ledgerEntries,
  }) : splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);
}
