import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/transactions/data/models/ledger_entry_persistence_model.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_split_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';

/// Persistence representation of a [TransactionTemplate].
///
/// Merchant identity is stored as a string. Splits and ledger entries are
/// stored as nested persistence records, while the domain template's
/// aggregate invariants are revalidated by [toEntity].
final class TransactionTemplatePersistenceModel {
  static const String _kindField = 'kind';
  static const String _merchantIdField = 'merchantId';
  static const String _descriptionField = 'description';
  static const String _noteField = 'note';
  static const String _splitsField = 'splits';
  static const String _ledgerEntriesField = 'ledgerEntries';

  /// Financial meaning of generated transactions.
  final TransactionKind kind;

  /// Serialized merchant identifier associated with generated transactions.
  final String merchantId;

  /// Optional short description copied to generated transactions.
  final String? description;

  /// Optional free-form note copied to generated transactions.
  final String? note;

  /// Persisted allocation values copied to generated transactions.
  final List<TransactionSplitPersistenceModel> splits;

  /// Persisted account-impact values copied to generated transactions.
  final List<LedgerEntryPersistenceModel> ledgerEntries;

  /// Creates a transaction-template persistence model.
  ///
  /// The supplied collections are defensively copied and exposed as immutable
  /// lists. Transaction-template invariants are revalidated when [toEntity]
  /// reconstructs the domain value.
  TransactionTemplatePersistenceModel({
    required this.kind,
    required this.merchantId,
    required this.description,
    required this.note,
    required List<TransactionSplitPersistenceModel> splits,
    required List<LedgerEntryPersistenceModel> ledgerEntries,
  }) : splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);

  /// Creates a persistence model from the valid domain [template].
  factory TransactionTemplatePersistenceModel.fromEntity(
    TransactionTemplate template,
  ) {
    return TransactionTemplatePersistenceModel(
      kind: template.kind,
      merchantId: template.merchantId.value,
      description: template.description,
      note: template.note,
      splits: template.splits
          .map(TransactionSplitPersistenceModel.fromEntity)
          .toList(growable: false),
      ledgerEntries: template.ledgerEntries
          .map(LedgerEntryPersistenceModel.fromEntity)
          .toList(growable: false),
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [path] identifies this model's location in the containing persisted
  /// structure and is included in structural error paths, including paths for
  /// individual splits and ledger entries.
  ///
  /// Throws [PersistenceRecordException] when a field or nested list element
  /// has an invalid persisted shape or value.
  factory TransactionTemplatePersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);
      final rawSplits = reader.requiredList(_splitsField);
      final rawLedgerEntries = reader.requiredList(_ledgerEntriesField);

      return TransactionTemplatePersistenceModel(
        kind: readPersistenceEnum(
          reader: reader,
          field: _kindField,
          values: TransactionKind.values,
        ),
        merchantId: reader.requiredString(_merchantIdField),
        description: reader.optionalString(_descriptionField),
        note: reader.optionalString(_noteField),
        splits: <TransactionSplitPersistenceModel>[
          for (var index = 0; index < rawSplits.length; index++)
            TransactionSplitPersistenceModel.fromRecord(
              persistenceRecordFromListValue(
                rawSplits[index],
                field: '$_splitsField[$index]',
              ),
              path: '$path.$_splitsField[$index]',
            ),
        ],
        ledgerEntries: <LedgerEntryPersistenceModel>[
          for (var index = 0; index < rawLedgerEntries.length; index++)
            LedgerEntryPersistenceModel.fromRecord(
              persistenceRecordFromListValue(
                rawLedgerEntries[index],
                field: '$_ledgerEntriesField[$index]',
              ),
              path: '$path.$_ledgerEntriesField[$index]',
            ),
        ],
      );
    });
  }

  /// Converts this model to its nested primitive persistence record
  /// representation.
  ///
  /// The splits and ledger entries retain their current list order.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _kindField: kind.name,
      _merchantIdField: merchantId,
      _descriptionField: description,
      _noteField: note,
      _splitsField: splits
          .map((split) => split.toRecord())
          .toList(growable: false),
      _ledgerEntriesField: ledgerEntries
          .map((entry) => entry.toRecord())
          .toList(growable: false),
    };
  }

  /// Reconstructs the domain [TransactionTemplate] represented by this model.
  ///
  /// Throws [ArgumentError] when a persisted identifier or nested value is
  /// invalid, or when the reconstructed template violates domain invariants.
  TransactionTemplate toEntity() {
    return TransactionTemplate(
      kind: kind,
      merchantId: MerchantId.fromString(merchantId),
      description: description,
      note: note,
      splits: splits.map((split) => split.toEntity()).toList(growable: false),
      ledgerEntries: ledgerEntries
          .map((entry) => entry.toEntity())
          .toList(growable: false),
    );
  }
}
