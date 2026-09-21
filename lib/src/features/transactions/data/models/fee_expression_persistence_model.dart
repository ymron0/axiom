import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/fee_expression.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of a [FeeExpression].
///
/// The concrete expression type is stored using an explicit discriminator.
///
/// Supported persistence types are:
///
/// - `percentage`;
/// - `assetAmount`.
final class FeeExpressionPersistenceModel {
  static const String _typeField = 'type';
  static const String _percentageField = 'percentage';
  static const String _amountField = 'amount';

  static const String _percentageType = 'percentage';
  static const String _assetAmountType = 'assetAmount';

  /// Persisted expression discriminator.
  final String type;

  /// Percentage value for percentage expressions.
  final Decimal? percentage;

  /// Asset amount for asset-amount expressions.
  final AssetAmountPersistenceModel? assetAmount;

  const FeeExpressionPersistenceModel._({
    required this.type,
    required this.percentage,
    required this.assetAmount,
  });

  /// Creates a percentage persistence model.
  factory FeeExpressionPersistenceModel.percentage(Decimal percentage) {
    return FeeExpressionPersistenceModel._(
      type: _percentageType,
      percentage: percentage,
      assetAmount: null,
    );
  }

  /// Creates an asset-amount persistence model.
  factory FeeExpressionPersistenceModel.assetAmount(
    AssetAmountPersistenceModel amount,
  ) {
    return FeeExpressionPersistenceModel._(
      type: _assetAmountType,
      percentage: null,
      assetAmount: amount,
    );
  }

  /// Creates the persistence representation of [expression].
  factory FeeExpressionPersistenceModel.fromEntity(FeeExpression expression) {
    return switch (expression) {
      PercentageFeeExpression(:final percentage) =>
        FeeExpressionPersistenceModel.percentage(percentage),

      AssetAmountFeeExpression(:final amount) =>
        FeeExpressionPersistenceModel.assetAmount(
          AssetAmountPersistenceModel.fromEntity(amount),
        ),
    };
  }

  /// Reconstructs a persistence model from [record].
  factory FeeExpressionPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);
      final type = reader.requiredString(_typeField);

      return switch (type) {
        _percentageType => FeeExpressionPersistenceModel.percentage(
          readPersistenceDecimal(reader, _percentageField),
        ),

        _assetAmountType => FeeExpressionPersistenceModel.assetAmount(
          AssetAmountPersistenceModel.fromRecord(
            reader.requiredMap(_amountField),
            path: '$path.$_amountField',
          ),
        ),

        _ => throw PersistenceRecordException(
          field: _typeField,
          reason: 'Unsupported fee expression type.',
        ),
      };
    });
  }

  /// Converts this model into its persistence representation.
  PersistenceRecord toRecord() {
    return switch (type) {
      _percentageType => <String, Object?>{
        _typeField: _percentageType,
        _percentageField: percentage!.toString(),
      },

      _assetAmountType => <String, Object?>{
        _typeField: _assetAmountType,
        _amountField: assetAmount!.toRecord(),
      },

      // coverage:ignore-start
      _ => throw StateError(
        'Unsupported fee expression persistence type: $type.',
      ),
      // coverage:ignore-end
    };
  }

  /// Reconstructs the domain fee expression.
  FeeExpression toEntity() {
    return switch (type) {
      _percentageType => PercentageFeeExpression(percentage: percentage!),

      _assetAmountType => AssetAmountFeeExpression(
        amount: assetAmount!.toEntity(),
      ),

      // coverage:ignore-start
      _ => throw StateError(
        'Unsupported fee expression persistence type: $type.',
      ),
      // coverage:ignore-end
    };
  }
}
