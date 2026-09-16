import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';

/// Persistence representation of a [TransactionSplit].
///
/// The two amounts are stored as nested [AssetAmountPersistenceModel] records.
/// Allocation identifiers are stored as nullable strings because a split may
/// target a category, a jar, or both.
final class TransactionSplitPersistenceModel {
  /// Creates a transaction-split persistence model.
  ///
  /// This constructor performs structural assignment only. Split invariants
  /// are revalidated when [toEntity] reconstructs the domain value.
  const TransactionSplitPersistenceModel({
    required this.transactionAmount,
    required this.valuationAmount,
    required this.categoryId,
    required this.jarId,
  });

  static const String _transactionAmountField = 'transactionAmount';
  static const String _valuationAmountField = 'valuationAmount';
  static const String _categoryIdField = 'categoryId';
  static const String _jarIdField = 'jarId';

  /// Persisted portion of the transaction amount allocated by this split.
  final AssetAmountPersistenceModel transactionAmount;

  /// Persisted valuation-currency representation of this allocation.
  final AssetAmountPersistenceModel valuationAmount;

  /// Serialized category identifier, when this split has a category target.
  final String? categoryId;

  /// Serialized jar identifier, when this split has a jar target.
  final String? jarId;

  /// Creates a persistence model from the valid domain [split].
  factory TransactionSplitPersistenceModel.fromEntity(TransactionSplit split) {
    return TransactionSplitPersistenceModel(
      transactionAmount: AssetAmountPersistenceModel.fromEntity(
        split.transactionAmount,
      ),
      valuationAmount: AssetAmountPersistenceModel.fromEntity(
        split.valuationAmount,
      ),
      categoryId: split.categoryId?.value,
      jarId: split.jarId?.value,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [path] identifies this model's location in the containing persisted
  /// structure and is included in structural error paths.
  ///
  /// Throws [PersistenceRecordException] when a required nested amount or
  /// field is missing, has the wrong type, contains an invalid decimal, or
  /// contains an unsupported enum value.
  factory TransactionSplitPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      return TransactionSplitPersistenceModel(
        transactionAmount: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_transactionAmountField),
          path: '$path.$_transactionAmountField',
        ),
        valuationAmount: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_valuationAmountField),
          path: '$path.$_valuationAmountField',
        ),
        categoryId: reader.optionalString(_categoryIdField),
        jarId: reader.optionalString(_jarIdField),
      );
    });
  }

  /// Converts this model to its nested persistence record representation.
  ///
  /// [categoryId] and [jarId] remain `null` when the corresponding allocation
  /// target is absent.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _transactionAmountField: transactionAmount.toRecord(),
      _valuationAmountField: valuationAmount.toRecord(),
      _categoryIdField: categoryId,
      _jarIdField: jarId,
    };
  }

  /// Reconstructs the domain [TransactionSplit] represented by this model.
  ///
  /// Throws [ArgumentError] when a persisted identifier is invalid or the
  /// reconstructed split violates its domain invariants.
  TransactionSplit toEntity() {
    return TransactionSplit(
      transactionAmount: transactionAmount.toEntity(),
      valuationAmount: valuationAmount.toEntity(),
      categoryId: categoryId == null
          ? null
          : CategoryId.fromString(categoryId!),
      jarId: jarId == null ? null : JarId.fromString(jarId!),
    );
  }
}
