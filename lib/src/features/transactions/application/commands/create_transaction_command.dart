import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';

/// Input required to create and persist a new transaction.
///
/// Generated identity, version, audit metadata, and deletion state are
/// intentionally excluded.
final class CreateTransactionCommand {
  /// Creates a transaction creation command.
  CreateTransactionCommand({
    required this.kind,
    required this.merchantId,
    required this.effectiveAt,
    this.description,
    this.note,
    required this.state,
    required List<TransactionSplit> splits,
    required List<LedgerEntry> ledgerEntries,
  }) : splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);

  /// The financial meaning of the transaction.
  final TransactionKind kind;

  /// The merchant associated with the transaction.
  final MerchantId merchantId;

  /// The instant at which the transaction is financially effective.
  final DateTime effectiveAt;

  /// An optional short description of the transaction.
  final String? description;

  /// An optional free-form note associated with the transaction.
  final String? note;

  /// The transaction's initial lifecycle state.
  final TransactionState state;

  /// The transaction's allocation inputs.
  final List<TransactionSplit> splits;

  /// The transaction's account-impact inputs.
  final List<LedgerEntry> ledgerEntries;
}
