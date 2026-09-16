import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';

/// Persistence representation of [Settings].
///
/// This type forms the mapping boundary between the Settings domain model and
/// the storage representation written to Sembast.
///
/// The domain entity is deliberately not serialized directly. Keeping the
/// persistence representation separate allows the persisted record shape to
/// evolve independently from the domain model and gives future database
/// migrations an explicit storage format to target.
///
/// Persisted values use storage-friendly primitives only. In particular,
/// [Settings.valuationCurrencyId] is stored as its string value and is rebuilt
/// as an [AssetId] when the domain entity is reconstructed.
///
/// Cross-aggregate invariants are not validated here. Whether
/// [valuationCurrencyId] identifies an existing [Currency] remains an
/// application-level responsibility because this mapper must not depend on
/// the Assets repository.
final class SettingsPersistenceModel {
  /// Persisted field containing the valuation currency identifier.
  ///
  /// This field name becomes part of the persistent database schema once
  /// released and must not be renamed without an appropriate database
  /// migration.
  static const String valuationCurrencyIdField = 'valuationCurrencyId';

  /// Creates a persistence model from validated persistence values.
  const SettingsPersistenceModel._({required this.valuationCurrencyId});

  /// String representation of the configured valuation currency identifier.
  final String valuationCurrencyId;

  /// Creates a persistence model from the current domain [settings].
  ///
  /// Domain values are assumed to already satisfy domain invariants.
  factory SettingsPersistenceModel.fromEntity(Settings settings) {
    return SettingsPersistenceModel._(
      valuationCurrencyId: settings.valuationCurrencyId.value,
    );
  }

  /// Reconstructs a persistence model from an untrusted persisted [record].
  ///
  /// Persisted data must never be trusted merely because it originated from
  /// this application. The record is therefore read through
  /// [PersistenceRecordReader], which validates the required field shape.
  ///
  /// Throws [PersistenceRecordException] when the persisted representation is
  /// malformed.
  factory SettingsPersistenceModel.fromRecord(PersistenceRecord record) {
    final reader = PersistenceRecordReader(record);

    return SettingsPersistenceModel._(
      valuationCurrencyId: reader.requiredString(valuationCurrencyIdField),
    );
  }

  /// Converts this persistence model into the record stored by Sembast.
  ///
  /// The returned map contains persistence primitives only and does not expose
  /// domain value objects to the storage layer.
  PersistenceRecord toRecord() {
    return <String, Object?>{valuationCurrencyIdField: valuationCurrencyId};
  }

  /// Reconstructs the domain [Settings] entity.
  ///
  /// Throws [PersistenceRecordException] when persisted values cannot satisfy
  /// the current domain/value-object invariants.
  Settings toEntity() {
    try {
      return Settings(
        valuationCurrencyId: AssetId.fromString(valuationCurrencyId),
      );
    } on ArgumentError {
      throw const PersistenceRecordException(
        field: valuationCurrencyIdField,
        reason:
            'Persisted valuation currency identifier violates current '
            'domain invariants.',
      );
    }
  }
}
