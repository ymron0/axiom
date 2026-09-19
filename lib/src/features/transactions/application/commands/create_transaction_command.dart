import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';

/// Input required to create and persist a new transaction.
final class CreateTransactionCommand {
  final TransactionKind kind;

  final MerchantId merchantId;

  final DateTime effectiveAt;

  final String? description;

  final String? note;

  final TransactionState state;

  /// Reusable metadata attached to the new transaction.
  final List<TagId> tagIds;

  final List<TransactionSplit> splits;

  final List<LedgerEntry> ledgerEntries;

  /// Creates a transaction creation command.
  CreateTransactionCommand({
    required this.kind,
    required this.merchantId,
    required this.effectiveAt,
    this.description,
    this.note,
    required this.state,
    List<TagId> tagIds = const [],
    required List<TransactionSplit> splits,
    required List<LedgerEntry> ledgerEntries,
  }) : tagIds = List.unmodifiable(tagIds),
       splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);
}
