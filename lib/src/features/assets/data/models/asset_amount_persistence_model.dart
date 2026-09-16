import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of an [AssetAmount] embedded in a transaction.
///
/// The model contains only persistence-safe values: the asset identifier is a
/// string, the direction is encoded by its enum name, and decimal values are
/// written as strings so persistence never introduces binary floating-point
/// rounding.
final class AssetAmountPersistenceModel {
  /// Creates an asset-amount persistence model.
  ///
  /// This constructor performs structural assignment only. Domain validation
  /// is applied when [toEntity] reconstructs the [AssetAmount].
  const AssetAmountPersistenceModel({
    required this.assetId,
    required this.amount,
    required this.direction,
  });

  static const String _assetIdField = 'assetId';
  static const String _amountField = 'amount';
  static const String _directionField = 'direction';

  /// Serialized identifier of the asset described by this amount.
  final String assetId;

  /// Exact decimal magnitude of the amount.
  ///
  /// [toRecord] serializes this value as a base-10 string.
  final Decimal amount;

  /// Direction of the amount's balance impact.
  final AssetAmountDirection direction;

  /// Creates a persistence model from the valid domain [amount].
  ///
  /// This performs structural translation and preserves the exact decimal
  /// value and direction.
  factory AssetAmountPersistenceModel.fromEntity(AssetAmount amount) {
    return AssetAmountPersistenceModel(
      assetId: amount.assetId.value,
      amount: amount.amount,
      direction: amount.direction,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [path] identifies this model's location in the containing persisted
  /// structure and is included in structural error paths.
  ///
  /// Throws [PersistenceRecordException] when a required field is missing,
  /// has the wrong type, contains an invalid decimal, or contains an
  /// unsupported direction name.
  factory AssetAmountPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      return AssetAmountPersistenceModel(
        assetId: reader.requiredString(_assetIdField),
        amount: readPersistenceDecimal(reader, _amountField),
        direction: readPersistenceEnum(
          reader: reader,
          field: _directionField,
          values: AssetAmountDirection.values,
        ),
      );
    });
  }

  /// Converts this model to its persistence record representation.
  ///
  /// The record contains [assetId], [amount] as a decimal string, and
  /// [direction] as [Enum.name].
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _assetIdField: assetId,
      _amountField: amount.toString(),
      _directionField: direction.name,
    };
  }

  /// Reconstructs the domain [AssetAmount] represented by this model.
  ///
  /// Throws [ArgumentError] when [assetId] is invalid or when the persisted
  /// amount violates the domain invariants.
  AssetAmount toEntity() {
    return AssetAmount(
      assetId: AssetId.fromString(assetId),
      amount: amount,
      direction: direction,
    );
  }
}
