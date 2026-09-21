import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of a [LedgerEntry].
///
/// Percentage metadata is optional so records written before percentage-fee
/// support remain valid without migration.
final class LedgerEntryPersistenceModel {
  /// Creates a ledger-entry persistence model.
  const LedgerEntryPersistenceModel({
    required this.accountId,
    required this.transactionAmount,
    required this.accountAmount,
    required this.valuationAmount,
    required this.role,
    this.feePercentage,
  });

  static const String _accountIdField = 'accountId';
  static const String _transactionAmountField = 'transactionAmount';
  static const String _accountAmountField = 'accountAmount';
  static const String _valuationAmountField = 'valuationAmount';
  static const String _roleField = 'role';
  static const String _feePercentageField = 'feePercentage';

  /// Serialized identifier of the affected account.
  final String accountId;

  /// Persisted transaction amount.
  final AssetAmountPersistenceModel transactionAmount;

  /// Persisted account amount.
  final AssetAmountPersistenceModel accountAmount;

  /// Persisted valuation amount.
  final AssetAmountPersistenceModel valuationAmount;

  /// Persisted ledger-entry role.
  final LedgerEntryRole role;

  /// Optional percentage metadata for a percentage fee.
  final Decimal? feePercentage;

  /// Creates a persistence model from [entry].
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
      feePercentage: entry.feePercentage,
    );
  }

  /// Reconstructs a persistence model from [record].
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
        feePercentage: _readOptionalDecimal(reader, _feePercentageField),
      );
    });
  }

  /// Converts this model into its persistence representation.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _accountIdField: accountId,
      _transactionAmountField: transactionAmount.toRecord(),
      _accountAmountField: accountAmount.toRecord(),
      _valuationAmountField: valuationAmount.toRecord(),
      _roleField: role.name,
      if (feePercentage != null) _feePercentageField: feePercentage.toString(),
    };
  }

  /// Reconstructs the domain ledger entry.
  LedgerEntry toEntity() {
    return LedgerEntry(
      accountId: AccountId.fromString(accountId),
      transactionAmount: transactionAmount.toEntity(),
      accountAmount: accountAmount.toEntity(),
      valuationAmount: valuationAmount.toEntity(),
      role: role,
      feePercentage: feePercentage,
    );
  }

  static Decimal? _readOptionalDecimal(
    PersistenceRecordReader reader,
    String field,
  ) {
    final rawValue = reader.optionalString(field);

    if (rawValue == null) {
      return null;
    }

    try {
      return Decimal.parse(rawValue);
    } on FormatException {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a valid decimal string.',
      );
    }
  }
}
