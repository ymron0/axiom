import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/transactions/data/models/recurrence_amount_end_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';

/// Persistence representation of [RecurrenceEnd] termination conditions.
///
/// Calendar dates are stored as `YYYY-MM-DD` strings. The optional amount
/// condition is stored as a nested persistence model. This type only maps
/// values; [toEntity] revalidates the recurrence-end invariants.
final class RecurrenceEndPersistenceModel {
  static const String _untilField = 'until';
  static const String _countField = 'count';
  static const String _amountField = 'amount';

  /// Inclusive final calendar date permitted by the recurrence, when present.
  final CalendarDate? until;

  /// Maximum number of occurrences, including the first occurrence, when
  /// present.
  final int? count;

  /// Optional cumulative monetary termination condition.
  final RecurrenceAmountEndPersistenceModel? amount;

  /// Creates a recurrence-end persistence model.
  ///
  /// This constructor performs structural assignment only. Recurrence-end
  /// invariants are revalidated when [toEntity] reconstructs the domain value.
  const RecurrenceEndPersistenceModel({
    required this.until,
    required this.count,
    required this.amount,
  });

  /// Creates a persistence model from the valid domain [end].
  factory RecurrenceEndPersistenceModel.fromEntity(RecurrenceEnd end) {
    return RecurrenceEndPersistenceModel(
      until: end.until,
      count: end.count,
      amount: end.amount == null
          ? null
          : RecurrenceAmountEndPersistenceModel.fromEntity(end.amount!),
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [path] identifies this model's location in the containing persisted
  /// structure and is included in structural error paths.
  ///
  /// Throws [PersistenceRecordException] when a field or nested amount has an
  /// invalid persisted shape or value.
  factory RecurrenceEndPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);
      final rawAmount = reader.optionalMap(_amountField);

      return RecurrenceEndPersistenceModel(
        until: readOptionalCalendarDate(reader, _untilField),
        count: reader.optionalInt(_countField),
        amount: rawAmount == null
            ? null
            : RecurrenceAmountEndPersistenceModel.fromRecord(
                rawAmount,
                path: '$path.$_amountField',
              ),
      );
    });
  }

  /// Converts this model to its primitive persistence record representation.
  ///
  /// Optional conditions remain `null` when they are not configured.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _untilField: until?.toString(),
      _countField: count,
      _amountField: amount?.toRecord(),
    };
  }

  /// Reconstructs the domain [RecurrenceEnd] represented by this model.
  ///
  /// Throws [ArgumentError] when the persisted conditions violate the domain
  /// invariants.
  RecurrenceEnd toEntity() {
    return RecurrenceEnd(
      until: until,
      count: count,
      amount: amount?.toEntity(),
    );
  }
}
