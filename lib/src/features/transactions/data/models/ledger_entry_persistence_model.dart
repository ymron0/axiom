import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';

/// Persistence representation of a [LedgerEntry].
///
/// The three monetary representations are stored as nested
/// [AssetAmountPersistenceModel] records. The account and role are encoded as
/// primitive persistence values and domain relationships are revalidated when
/// the model is converted back to a [LedgerEntry].
final class LedgerEntryPersistenceModel {
  /// Creates a ledger-entry persistence model.
  ///
  /// This constructor performs structural assignment only. Ledger-entry
  /// invariants are revalidated when [toEntity] reconstructs the domain value.
  const LedgerEntryPersistenceModel({
    required this.accountId,
    required this.transactionAmount,
    required this.accountAmount,
    required this.valuationAmount,
    required this.role,
  });

  static const String _accountIdField = 'accountId';
  static const String _transactionAmountField = 'transactionAmount';
  static const String _accountAmountField = 'accountAmount';
  static const String _valuationAmountField = 'valuationAmount';
  static const String _roleField = 'role';

  /// Serialized identifier of the affected account.
  final String accountId;

  /// Persisted amount in the transaction's currency.
  final AssetAmountPersistenceModel transactionAmount;

  /// Persisted balance impact in the affected account's currency.
  final AssetAmountPersistenceModel accountAmount;

  /// Persisted value in the configured valuation currency.
  final AssetAmountPersistenceModel valuationAmount;

  /// Persisted economic role of this ledger entry.
  final LedgerEntryRole role;

  /// Creates a persistence model from the valid domain [entry].
  factory LedgerEntryPersistenceModel.fromEntity(LedgerEntry entry) {
    return LedgerEntryPersistenceModel(
      accountId: entry.accountId.value,
      transactionAmount: AssetAmountPersistenceModel.fromEntity(
        entry.transactionAmount,
      ),
      accountAmount: AssetAmountPersistenceModel.fromEntity(
        entry.accountAmount,
      ),
      valuationAmount: AssetAmountPersistenceModel.fromEntity(
        entry.valuationAmount,
      ),
      role: entry.role,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [path] identifies this model's location in the containing persisted
  /// structure and is included in structural error paths.
  ///
  /// Throws [PersistenceRecordException] when a required field or nested
  /// amount is missing, has the wrong type, contains an invalid decimal, or
  /// contains an unsupported enum value.
  factory LedgerEntryPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      return LedgerEntryPersistenceModel(
        accountId: reader.requiredString(_accountIdField),
        transactionAmount: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_transactionAmountField),
          path: '$path.$_transactionAmountField',
        ),
        accountAmount: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_accountAmountField),
          path: '$path.$_accountAmountField',
        ),
        valuationAmount: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_valuationAmountField),
          path: '$path.$_valuationAmountField',
        ),
        role: readPersistenceEnum(
          reader: reader,
          field: _roleField,
          values: LedgerEntryRole.values,
        ),
      );
    });
  }

  /// Converts this model to its nested persistence record representation.
  ///
  /// Decimal values are serialized by the nested amount models as exact
  /// base-10 strings. The role is serialized using [Enum.name].
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _accountIdField: accountId,
      _transactionAmountField: transactionAmount.toRecord(),
      _accountAmountField: accountAmount.toRecord(),
      _valuationAmountField: valuationAmount.toRecord(),
      _roleField: role.name,
    };
  }

  /// Reconstructs the domain [LedgerEntry] represented by this model.
  ///
  /// Throws [ArgumentError] when the persisted account identifier is invalid
  /// or the reconstructed entry violates its domain invariants.
  LedgerEntry toEntity() {
    return LedgerEntry(
      accountId: AccountId.fromString(accountId),
      transactionAmount: transactionAmount.toEntity(),
      accountAmount: accountAmount.toEntity(),
      valuationAmount: valuationAmount.toEntity(),
      role: role,
    );
  }
}
