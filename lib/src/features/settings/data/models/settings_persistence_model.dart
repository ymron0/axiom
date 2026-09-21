import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/enums/planned_transaction_generation_horizon.dart';

/// Persistence representation of [Settings].
///
/// This type forms the mapping boundary between the Settings domain model and
/// the storage representation written to Sembast.
///
/// Existing records created before either transaction-policy setting was
/// introduced may not contain those fields. Missing policy fields are
/// interpreted as `true` so upgrades preserve the historically permissive
/// behavior.
///
/// Existing records created before planned transaction generation preferences
/// were introduced default to [PlannedTransactionGenerationHorizon.twoYears].
final class SettingsPersistenceModel {
  /// Persisted field containing the valuation currency identifier.
  static const String valuationCurrencyIdField = 'valuationCurrencyId';

  /// Persisted field containing the planned transaction generation horizon.
  static const String plannedTransactionGenerationHorizonField =
      'plannedTransactionGenerationHorizon';

  /// Persisted field controlling whether transactions may exceed budgets.
  static const String allowOverbudgetTransactionsField =
      'allowOverbudgetTransactions';

  /// Persisted field controlling whether jar balances may become negative.
  static const String allowNegativeJarBalancesField =
      'allowNegativeJarBalances';

  /// Creates a persistence model from validated persistence values.
  const SettingsPersistenceModel._({
    required this.valuationCurrencyId,
    required this.plannedTransactionGenerationHorizon,
    required this.allowOverbudgetTransactions,
    required this.allowNegativeJarBalances,
  });

  /// String representation of the configured valuation currency identifier.
  final String valuationCurrencyId;

  /// Preferred horizon for planned transaction materialization.
  final PlannedTransactionGenerationHorizon plannedTransactionGenerationHorizon;

  /// Whether overbudget transactions are allowed.
  final bool allowOverbudgetTransactions;

  /// Whether negative jar balances are allowed.
  final bool allowNegativeJarBalances;

  /// Creates a persistence model from the current domain [settings].
  factory SettingsPersistenceModel.fromEntity(Settings settings) {
    return SettingsPersistenceModel._(
      valuationCurrencyId: settings.valuationCurrencyId.value,
      plannedTransactionGenerationHorizon:
          settings.plannedTransactionGenerationHorizon,
      allowOverbudgetTransactions: settings.allowOverbudgetTransactions,
      allowNegativeJarBalances: settings.allowNegativeJarBalances,
    );
  }

  /// Reconstructs a persistence model from an untrusted persisted [record].
  ///
  /// Older settings records that do not contain transaction-policy fields
  /// default those policies to `true`.
  ///
  /// Older records without a planned-generation horizon default to two years.
  factory SettingsPersistenceModel.fromRecord(PersistenceRecord record) {
    final reader = PersistenceRecordReader(record);

    final plannedTransactionGenerationHorizon =
        reader.contains(plannedTransactionGenerationHorizonField)
        ? readPersistenceEnum<PlannedTransactionGenerationHorizon>(
            reader: reader,
            field: plannedTransactionGenerationHorizonField,
            values: PlannedTransactionGenerationHorizon.values,
          )
        : PlannedTransactionGenerationHorizon.twoYears;

    final allowOverbudgetTransactions =
        reader.contains(allowOverbudgetTransactionsField)
        ? reader.requiredBool(allowOverbudgetTransactionsField)
        : true;

    final allowNegativeJarBalances =
        reader.contains(allowNegativeJarBalancesField)
        ? reader.requiredBool(allowNegativeJarBalancesField)
        : true;

    return SettingsPersistenceModel._(
      valuationCurrencyId: reader.requiredString(valuationCurrencyIdField),
      plannedTransactionGenerationHorizon: plannedTransactionGenerationHorizon,
      allowOverbudgetTransactions: allowOverbudgetTransactions,
      allowNegativeJarBalances: allowNegativeJarBalances,
    );
  }

  /// Converts this persistence model into the record stored by Sembast.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      valuationCurrencyIdField: valuationCurrencyId,
      plannedTransactionGenerationHorizonField:
          plannedTransactionGenerationHorizon.name,
      allowOverbudgetTransactionsField: allowOverbudgetTransactions,
      allowNegativeJarBalancesField: allowNegativeJarBalances,
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
        plannedTransactionGenerationHorizon:
            plannedTransactionGenerationHorizon,
        allowOverbudgetTransactions: allowOverbudgetTransactions,
        allowNegativeJarBalances: allowNegativeJarBalances,
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
