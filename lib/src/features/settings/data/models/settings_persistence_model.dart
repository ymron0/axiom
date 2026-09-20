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
/// Existing records created before `allowOverbudgetTransactions` was introduced
/// do not contain that field. Those records are interpreted as allowing
/// overbudget transactions so upgrading does not silently introduce stricter
/// transaction behavior.
final class SettingsPersistenceModel {
  /// Persisted field containing the valuation currency identifier.
  static const String valuationCurrencyIdField = 'valuationCurrencyId';

  /// Persisted field controlling whether transactions may exceed budgets.
  static const String allowOverbudgetTransactionsField =
      'allowOverbudgetTransactions';

  /// Creates a persistence model from validated persistence values.
  const SettingsPersistenceModel._({
    required this.valuationCurrencyId,
    required this.allowOverbudgetTransactions,
  });

  /// String representation of the configured valuation currency identifier.
  final String valuationCurrencyId;

  /// Whether overbudget transactions are allowed.
  final bool allowOverbudgetTransactions;

  /// Creates a persistence model from the current domain [settings].
  factory SettingsPersistenceModel.fromEntity(Settings settings) {
    return SettingsPersistenceModel._(
      valuationCurrencyId: settings.valuationCurrencyId.value,
      allowOverbudgetTransactions: settings.allowOverbudgetTransactions,
    );
  }

  /// Reconstructs a persistence model from an untrusted persisted [record].
  ///
  /// Older settings records that do not contain
  /// [allowOverbudgetTransactionsField] default to `true`.
  ///
  /// If the field exists, it must contain a valid boolean.
  factory SettingsPersistenceModel.fromRecord(PersistenceRecord record) {
    final reader = PersistenceRecordReader(record);

    final allowOverbudgetTransactions =
        reader.contains(allowOverbudgetTransactionsField)
        ? reader.requiredBool(allowOverbudgetTransactionsField)
        : true;

    return SettingsPersistenceModel._(
      valuationCurrencyId: reader.requiredString(valuationCurrencyIdField),
      allowOverbudgetTransactions: allowOverbudgetTransactions,
    );
  }

  /// Converts this persistence model into the record stored by Sembast.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      valuationCurrencyIdField: valuationCurrencyId,
      allowOverbudgetTransactionsField: allowOverbudgetTransactions,
    };
  }

  /// Reconstructs the domain [Settings] entity.
  ///
  /// Throws [PersistenceRecordException] when persisted values cannot satisfy
  /// the current domain/value-object invariants.
  Settings toEntity() {
    try {
      return Settings(
        valuationCurrencyId: AssetId.fromString(valuationCurrencyId),
        allowOverbudgetTransactions: allowOverbudgetTransactions,
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
