import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';

/// Input required to create an offset of an existing transaction.
final class CreateTransactionOffsetCommand {
  final TransactionId originalTransactionId;

  final TransactionOffsetKind offsetKind;

  final MerchantId merchantId;

  final DateTime effectiveAt;

  final String? description;

  final String? note;

  /// Reusable metadata attached to the new offset transaction.
  final List<TagId> tagIds;

  final List<TransactionSplit> splits;

  final List<LedgerEntry> ledgerEntries;

  /// Creates a transaction-offset command.
  CreateTransactionOffsetCommand({
    required this.originalTransactionId,
    required this.offsetKind,
    required this.merchantId,
    required this.effectiveAt,
    this.description,
    this.note,
    List<TagId> tagIds = const [],
    required List<TransactionSplit> splits,
    required List<LedgerEntry> ledgerEntries,
  }) : tagIds = List.unmodifiable(tagIds),
       splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);
}
