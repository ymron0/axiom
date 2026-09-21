import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/transactions/data/models/fee_expression_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of a [LedgerEntry].
///
/// Fee expressions are persisted explicitly.
///
/// ## Backward compatibility
///
/// Older records may contain the former `feePercentage` field.
///
/// Such records are interpreted as follows:
///
/// - a fee with `feePercentage` becomes a percentage fee expression;
/// - a fee without `feePercentage` becomes an asset-amount fee expression
///   using its persisted transaction amount;
/// - non-fee entries remain without a fee expression.
///
/// New records use `feeExpression` exclusively.
final class LedgerEntryPersistenceModel {
  static const String _accountIdField = 'accountId';
  static const String _transactionAmountField = 'transactionAmount';
  static const String _accountAmountField = 'accountAmount';
  static const String _valuationAmountField = 'valuationAmount';
  static const String _roleField = 'role';
  static const String _feeExpressionField = 'feeExpression';

  /// Legacy field written by the previous fee representation.
  static const String _legacyFeePercentageField = 'feePercentage';

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

  /// Explicit persisted fee expression.
  final FeeExpressionPersistenceModel? feeExpression;

  /// Creates a ledger-entry persistence model.
  const LedgerEntryPersistenceModel({
    required this.accountId,
    required this.transactionAmount,
    required this.accountAmount,
    required this.valuationAmount,
    required this.role,
    this.feeExpression,
  });

  /// Creates a persistence model from [entry].
  factory LedgerEntryPersistenceModel.fromEntity(LedgerEntry entry) {
    final expression = entry.feeExpression;

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
      feeExpression: expression == null
          ? null
          : FeeExpressionPersistenceModel.fromEntity(expression),
    );
  }

  /// Reconstructs a persistence model from [record].
  factory LedgerEntryPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      final transactionAmount = AssetAmountPersistenceModel.fromRecord(
        reader.requiredMap(_transactionAmountField),
        path: '$path.$_transactionAmountField',
      );

      final accountAmount = AssetAmountPersistenceModel.fromRecord(
        reader.requiredMap(_accountAmountField),
        path: '$path.$_accountAmountField',
      );

      final valuationAmount = AssetAmountPersistenceModel.fromRecord(
        reader.requiredMap(_valuationAmountField),
        path: '$path.$_valuationAmountField',
      );

      final role = readPersistenceEnum(
        reader: reader,
        field: _roleField,
        values: LedgerEntryRole.values,
      );

      final feeExpression = _readFeeExpression(
        reader: reader,
        role: role,
        transactionAmount: transactionAmount,
        path: path,
      );

      return LedgerEntryPersistenceModel(
        accountId: reader.requiredString(_accountIdField),
        transactionAmount: transactionAmount,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
        role: role,
        feeExpression: feeExpression,
      );
    });
  }

  /// Converts this model into its persistence representation.
  PersistenceRecord toRecord() {
    final expression = feeExpression;

    return <String, Object?>{
      _accountIdField: accountId,
      _transactionAmountField: transactionAmount.toRecord(),
      _accountAmountField: accountAmount.toRecord(),
      _valuationAmountField: valuationAmount.toRecord(),
      _roleField: role.name,
      if (expression != null) _feeExpressionField: expression.toRecord(),
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
      feeExpression: feeExpression?.toEntity(),
    );
  }

  static FeeExpressionPersistenceModel? _readFeeExpression({
    required PersistenceRecordReader reader,
    required LedgerEntryRole role,
    required AssetAmountPersistenceModel transactionAmount,
    required String path,
  }) {
    final expressionRecord = reader.optionalMap(_feeExpressionField);

    if (expressionRecord != null) {
      if (reader.contains(_legacyFeePercentageField)) {
        throw const PersistenceRecordException(
          field: _feeExpressionField,
          reason:
              'A ledger entry cannot contain both feeExpression and '
              'feePercentage.',
        );
      }

      return FeeExpressionPersistenceModel.fromRecord(
        expressionRecord,
        path: '$path.$_feeExpressionField',
      );
    }

    final legacyPercentage = _readOptionalDecimal(
      reader,
      _legacyFeePercentageField,
    );

    if (legacyPercentage != null) {
      return FeeExpressionPersistenceModel.percentage(legacyPercentage);
    }

    if (role == LedgerEntryRole.fee) {
      return FeeExpressionPersistenceModel.assetAmount(transactionAmount);
    }

    return null;
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
