import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/transactions/data/models/ledger_entry_persistence_model.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_split_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';

/// Persistence representation of one [Transaction] aggregate.
///
/// The Sembast record key contains the transaction identifier and is therefore
/// intentionally not duplicated in [toRecord].
///
/// Nested domain value objects are flattened into primitive maps and lists.
/// Domain-generated `dart_mappable` representations are deliberately not used
/// as the persisted format. This keeps the persistent schema independent from
/// generated domain serialization details.
///
/// [persistenceOrder] is storage metadata rather than domain state. It
/// preserves the insertion-order semantics required by [TransactionRepository].
///
/// Deleted transactions are never represented by this model. Transaction
/// deletion is physical, so every persisted record represents an active
/// transaction.
final class TransactionPersistenceModel {
  TransactionPersistenceModel._({
    required this.id,
    required this.persistenceOrder,
    required this.kind,
    required this.merchantId,
    required this.effectiveAt,
    required this.description,
    required this.note,
    required this.state,
    required List<TransactionSplitPersistenceModel> splits,
    required List<LedgerEntryPersistenceModel> ledgerEntries,
    required this.createdAt,
    required this.modifiedAt,
    required this.entityVersion,
  }) : splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries);

  /// Persistence field containing transaction insertion order.
  ///
  /// This is public because the concrete repository must sort Sembast records
  /// using this field.
  static const String persistenceOrderField = 'persistenceOrder';

  static const String _kindField = 'kind';
  static const String _merchantIdField = 'merchantId';
  static const String _effectiveAtField = 'effectiveAt';
  static const String _descriptionField = 'description';
  static const String _noteField = 'note';
  static const String _stateField = 'state';
  static const String _splitsField = 'splits';
  static const String _ledgerEntriesField = 'ledgerEntries';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Identifier represented by the Sembast record key.
  final String id;

  /// Monotonic insertion order used only by persistence.
  final int persistenceOrder;

  /// Financial meaning of the transaction.
  final TransactionKind kind;

  /// Persisted merchant identifier.
  final String merchantId;

  /// UTC effective instant.
  final DateTime effectiveAt;

  /// Optional transaction description.
  final String? description;

  /// Optional transaction note.
  final String? note;

  /// Lifecycle state of the transaction.
  final TransactionState state;

  /// Persisted transaction allocations.
  final List<TransactionSplitPersistenceModel> splits;

  /// Persisted account impacts.
  final List<LedgerEntryPersistenceModel> ledgerEntries;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC modification timestamp.
  final DateTime modifiedAt;

  /// Aggregate class version.
  final int entityVersion;

  /// Creates a persistence model from an active domain transaction.
  ///
  /// [persistenceOrder] must already have been allocated by the repository.
  ///
  /// Deleted entities are rejected because transaction deletion is physical
  /// and a deleted snapshot must never be written directly to the store.
  factory TransactionPersistenceModel.fromEntity(
    Transaction transaction, {
    required int persistenceOrder,
  }) {
    if (transaction.isDeleted) {
      throw ArgumentError.value(
        transaction,
        'transaction',
        'Deleted transactions cannot be persisted.',
      );
    }

    if (persistenceOrder <= 0) {
      throw ArgumentError.value(
        persistenceOrder,
        'persistenceOrder',
        'Persistence order must be greater than zero.',
      );
    }

    return TransactionPersistenceModel._(
      id: transaction.id.value,
      persistenceOrder: persistenceOrder,
      kind: transaction.kind,
      merchantId: transaction.merchantId.value,
      effectiveAt: transaction.effectiveAt.toUtc(),
      description: transaction.description,
      note: transaction.note,
      state: transaction.state,
      splits: transaction.splits
          .map(TransactionSplitPersistenceModel.fromEntity)
          .toList(growable: false),
      ledgerEntries: transaction.ledgerEntries
          .map(LedgerEntryPersistenceModel.fromEntity)
          .toList(growable: false),
      createdAt: transaction.createdAt.toUtc(),
      modifiedAt: transaction.modifiedAt.toUtc(),
      entityVersion: transaction.entityVersion,
    );
  }

  /// Reconstructs a persistence model from a Sembast record.
  ///
  /// [recordKey] is the authoritative transaction identifier.
  ///
  /// Stored data is treated as untrusted. Structural problems, invalid enums,
  /// malformed decimals, malformed dates, and invalid persistence metadata are
  /// translated into [PersistenceRecordException].
  factory TransactionPersistenceModel.fromRecord(
    String recordKey,
    PersistenceRecord record,
  ) {
    final reader = PersistenceRecordReader(record);

    final rawSplits = reader.requiredList(_splitsField);
    final rawLedgerEntries = reader.requiredList(_ledgerEntriesField);

    return TransactionPersistenceModel._(
      id: recordKey,
      persistenceOrder: readPersistenceOrder(record),
      kind: readPersistenceEnum(
        reader: reader,
        field: _kindField,
        values: TransactionKind.values,
      ),
      merchantId: reader.requiredString(_merchantIdField),
      effectiveAt: readPersistenceDateTime(reader, _effectiveAtField),
      description: reader.optionalString(_descriptionField),
      note: reader.optionalString(_noteField),
      state: readPersistenceEnum(
        reader: reader,
        field: _stateField,
        values: TransactionState.values,
      ),
      splits: <TransactionSplitPersistenceModel>[
        for (var index = 0; index < rawSplits.length; index++)
          TransactionSplitPersistenceModel.fromRecord(
            persistenceRecordFromListValue(
              rawSplits[index],
              field: '$_splitsField[$index]',
            ),
            path: '$_splitsField[$index]',
          ),
      ],
      ledgerEntries: <LedgerEntryPersistenceModel>[
        for (var index = 0; index < rawLedgerEntries.length; index++)
          LedgerEntryPersistenceModel.fromRecord(
            persistenceRecordFromListValue(
              rawLedgerEntries[index],
              field: '$_ledgerEntriesField[$index]',
            ),
            path: '$_ledgerEntriesField[$index]',
          ),
      ],
      createdAt: readPersistenceDateTime(reader, _createdAtField),
      modifiedAt: readPersistenceDateTime(reader, _modifiedAtField),
      entityVersion: readPositivePersistenceInt(reader, _entityVersionField),
    );
  }

  /// Reads and validates persistence insertion order from a raw record.
  ///
  /// This smaller operation exists so the repository can allocate the next
  /// insertion position without reconstructing every complete transaction.
  static int readPersistenceOrder(PersistenceRecord record) {
    final reader = PersistenceRecordReader(record);
    return readPositivePersistenceInt(reader, persistenceOrderField);
  }

  /// Converts this model to the primitive representation stored by Sembast.
  ///
  /// The transaction ID is omitted because it is represented by the Sembast
  /// record key.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      persistenceOrderField: persistenceOrder,
      _kindField: kind.name,
      _merchantIdField: merchantId,
      _effectiveAtField: effectiveAt.toUtc().toIso8601String(),
      _descriptionField: description,
      _noteField: note,
      _stateField: state.name,
      _splitsField: splits
          .map((split) => split.toRecord())
          .toList(growable: false),
      _ledgerEntriesField: ledgerEntries
          .map((entry) => entry.toRecord())
          .toList(growable: false),
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }

  /// Reconstructs the active domain aggregate represented by this model.
  ///
  /// Domain constructors are intentionally used rather than bypassed. If the
  /// persisted values violate current domain invariants, the record is corrupt
  /// and [PersistenceRecordException] is thrown.
  Transaction toEntity() {
    try {
      return Transaction(
        id: TransactionId.fromString(id),
        kind: kind,
        merchantId: MerchantId.fromString(merchantId),
        effectiveAt: effectiveAt,
        description: description,
        note: note,
        state: state,
        deletedAt: null,
        splits: splits.map((split) => split.toEntity()).toList(growable: false),
        ledgerEntries: ledgerEntries
            .map((entry) => entry.toEntity())
            .toList(growable: false),
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        entityVersion: entityVersion,
      );
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted transaction violates domain invariants.',
      );
    } on FormatException {
      throw const PersistenceRecordException(
        reason: 'Persisted transaction contains an invalid domain value.',
      );
    }
  }
}
