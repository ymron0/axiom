import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of the [AssetAmount] contained by a jar target.
///
/// Decimal quantities are represented as base-10 strings so persistence does
/// not introduce binary floating-point rounding.
final class JarTargetAmountPersistenceModel {
  static const String _assetIdField = 'assetId';
  static const String _directionField = 'direction';
  static const String _valueField = 'value';

  final String assetId;
  final AssetAmountDirection direction;
  final Decimal value;

  const JarTargetAmountPersistenceModel._({
    required this.assetId,
    required this.direction,
    required this.value,
  });

  factory JarTargetAmountPersistenceModel.fromEntity(AssetAmount amount) {
    return JarTargetAmountPersistenceModel._(
      assetId: amount.assetId.value,
      direction: amount.direction,
      value: amount.amount,
    );
  }

  factory JarTargetAmountPersistenceModel.fromRecord(PersistenceRecord record) {
    final reader = PersistenceRecordReader(record);

    return JarTargetAmountPersistenceModel._(
      assetId: reader.requiredString(_assetIdField),
      direction: readPersistenceEnum<AssetAmountDirection>(
        reader: reader,
        field: _directionField,
        values: AssetAmountDirection.values,
      ),
      value: readPersistenceDecimal(reader, _valueField),
    );
  }

  PersistenceRecord toRecord() {
    return <String, Object?>{
      _assetIdField: assetId,
      _directionField: direction.name,
      _valueField: value.toString(),
    };
  }

  AssetAmount toEntity() {
    try {
      return AssetAmount(
        assetId: AssetId.fromString(assetId),
        amount: value,
        direction: direction,
      );
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted jar target amount is invalid.',
      );
    }
  }
}
