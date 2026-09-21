import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_template_instantiation_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_occurrence_origin.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'transaction_template.mapper.dart';

/// Reusable transaction data owned by a recurring transaction series.
///
/// A template describes the financial shape to use when creating an occurrence.
///
/// It is not itself a financial event and therefore deliberately does not own:
///
/// - transaction identity;
/// - an effective instant;
/// - transaction lifecycle state;
/// - audit metadata;
/// - deletion state; or
/// - occurrence origin.
///
/// Those values belong to the materialized [Transaction] or the generation
/// workflow.
///
/// ## Transaction invariant ownership
///
/// Transaction-wide financial invariants remain owned by [Transaction].
///
/// This type deliberately does not duplicate validation such as:
///
/// - required primary ledger-entry count;
/// - direction required by the transaction kind;
/// - transfer entry structure; or
/// - split reconciliation.
///
/// [instantiate] delegates those checks to [Transaction] and translates an
/// invalid template shape into a
/// [TransactionTemplateInstantiationFailure].
///
/// ## Monetary semantics
///
/// Monetary values are copied exactly from the template into an occurrence.
///
/// A workflow that needs occurrence-date-specific FX valuation must supply a
/// template whose values have already been resolved before materialization.
///
/// ## Immutability
///
/// [tagIds], [splits], and [ledgerEntries] are defensively copied and exposed
/// as immutable collections.
@MappableClass()
final class TransactionTemplate with TransactionTemplateMappable {
  /// Financial meaning of generated transactions.
  final TransactionKind kind;

  /// Merchant associated with generated transactions.
  final MerchantId merchantId;

  /// Optional short description copied to generated transactions.
  final String? description;

  /// Optional free-form note copied to generated transactions.
  final String? note;

  /// Reusable metadata copied to generated transactions.
  final List<TagId> tagIds;

  /// Allocation values copied to generated transactions.
  final List<TransactionSplit> splits;

  /// Account-impact values copied to generated transactions.
  final List<LedgerEntry> ledgerEntries;

  /// Creates a reusable transaction template.
  @MappableConstructor()
  TransactionTemplate({
    required this.kind,
    required this.merchantId,
    String? description,
    String? note,
    List<TagId> tagIds = const [],
    required List<TransactionSplit> splits,
    required List<LedgerEntry> ledgerEntries,
  }) : description = normalizeOptionalText(description, 'description'),
       note = normalizeOptionalText(note, 'note'),
       tagIds = List.unmodifiable(tagIds),
       splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);

  /// Materializes this template as a transaction.
  ///
  /// [effectiveAt], [state], and [recurrenceOrigin] belong to the materialized
  /// transaction rather than the reusable template.
  ///
  /// Returns [TransactionTemplateInstantiationFailure] when the template does
  /// not satisfy the aggregate invariants owned by [Transaction].
  Result<Transaction, TransactionTemplateInstantiationFailure> instantiate({
    required DateTime effectiveAt,
    TransactionState state = TransactionState.planned,
    TransactionOccurrenceOrigin? recurrenceOrigin,
    Clock? clock,
  }) {
    try {
      final transaction = Transaction.create(
        kind: kind,
        merchantId: merchantId,
        effectiveAt: effectiveAt,
        description: description,
        note: note,
        state: state,
        recurrenceOrigin: recurrenceOrigin,
        tagIds: tagIds,
        splits: splits,
        ledgerEntries: ledgerEntries,
        clock: clock,
      );

      return Success(transaction);
    } on ArgumentError catch (error) {
      return TransactionTemplateInstantiationFailure(message: error.toString());
    }
  }
}
