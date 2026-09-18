import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/data/models/asset_amount_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';

/// Persistence representation of amount-based recurrence termination.
final class RecurrenceAmountEndPersistenceModel {
  static const String _targetAmountField = 'targetAmount';
  static const String _completionField = 'completion';

  final AssetAmountPersistenceModel targetAmount;
  final RecurrenceAmountCompletion completion;

  const RecurrenceAmountEndPersistenceModel({
    required this.targetAmount,
    required this.completion,
  });

  factory RecurrenceAmountEndPersistenceModel.fromEntity(
    RecurrenceAmountEnd amountEnd,
  ) {
    return RecurrenceAmountEndPersistenceModel(
      targetAmount: AssetAmountPersistenceModel.fromEntity(
        amountEnd.targetAmount,
      ),
      completion: amountEnd.completion,
    );
  }

  factory RecurrenceAmountEndPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      return RecurrenceAmountEndPersistenceModel(
        targetAmount: AssetAmountPersistenceModel.fromRecord(
          reader.requiredMap(_targetAmountField),
          path: '$path.$_targetAmountField',
        ),
        completion: readPersistenceEnum(
          reader: reader,
          field: _completionField,
          values: RecurrenceAmountCompletion.values,
        ),
      );
    });
  }

  PersistenceRecord toRecord() {
    return <String, Object?>{
      _targetAmountField: targetAmount.toRecord(),
      _completionField: completion.name,
    };
  }

  RecurrenceAmountEnd toEntity() {
    return RecurrenceAmountEnd(
      targetAmount: targetAmount.toEntity(),
      completion: completion,
    );
  }
}
