import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/transactions/data/models/recurrence_end_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';

/// Persistence representation of a [RecurrenceRule].
///
/// The rule stores its calendar anchor, frequency, interval, and optional
/// termination conditions. This type only maps values; [toEntity] revalidates
/// the recurrence-rule invariants.
final class RecurrenceRulePersistenceModel {
  static const String _startsOnField = 'startsOn';
  static const String _frequencyField = 'frequency';
  static const String _intervalField = 'interval';
  static const String _endField = 'end';

  /// First scheduled occurrence date.
  final CalendarDate startsOn;

  /// Calendar unit in which the recurrence advances.
  final RecurrenceFrequency frequency;

  /// Number of [frequency] units between consecutive occurrences.
  final int interval;

  /// Optional recurrence termination conditions.
  final RecurrenceEndPersistenceModel? end;

  /// Creates a recurrence-rule persistence model.
  ///
  /// This constructor performs structural assignment only. Recurrence-rule
  /// invariants are revalidated when [toEntity] reconstructs the domain value.
  const RecurrenceRulePersistenceModel({
    required this.startsOn,
    required this.frequency,
    required this.interval,
    required this.end,
  });

  /// Creates a persistence model from the valid domain [rule].
  factory RecurrenceRulePersistenceModel.fromEntity(RecurrenceRule rule) {
    return RecurrenceRulePersistenceModel(
      startsOn: rule.startsOn,
      frequency: rule.frequency,
      interval: rule.interval,
      end: rule.end == null
          ? null
          : RecurrenceEndPersistenceModel.fromEntity(rule.end!),
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [path] identifies this model's location in the containing persisted
  /// structure and is included in structural error paths.
  ///
  /// Throws [PersistenceRecordException] when a field or nested end condition
  /// has an invalid persisted shape or value.
  factory RecurrenceRulePersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);
      final rawEnd = reader.optionalMap(_endField);

      return RecurrenceRulePersistenceModel(
        startsOn: readCalendarDate(
          reader.requiredString(_startsOnField),
          field: _startsOnField,
        ),
        frequency: readPersistenceEnum(
          reader: reader,
          field: _frequencyField,
          values: RecurrenceFrequency.values,
        ),
        interval: reader.requiredInt(_intervalField),
        end: rawEnd == null
            ? null
            : RecurrenceEndPersistenceModel.fromRecord(
                rawEnd,
                path: '$path.$_endField',
              ),
      );
    });
  }

  /// Converts this model to its primitive persistence record representation.
  ///
  /// The optional end condition remains `null` when the rule is unbounded.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _startsOnField: startsOn.toString(),
      _frequencyField: frequency.name,
      _intervalField: interval,
      _endField: end?.toRecord(),
    };
  }

  /// Reconstructs the domain [RecurrenceRule] represented by this model.
  ///
  /// Throws [ArgumentError] when the persisted values violate the recurrence
  /// rule invariants.
  RecurrenceRule toEntity() {
    return RecurrenceRule(
      startsOn: startsOn,
      frequency: frequency,
      interval: interval,
      end: end?.toEntity(),
    );
  }
}
