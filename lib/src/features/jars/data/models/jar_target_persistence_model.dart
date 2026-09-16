import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/jars/data/models/jar_target_amount_persistence_model.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';

/// Persistence representation of one [JarTarget].
///
/// The target itself has no independent persistence identity. It is persisted
/// as part of its owning jar aggregate.
final class JarTargetPersistenceModel {
  static const String _amountField = 'amount';
  static const String _effectiveFromField = 'effectiveFrom';
  static const String _effectiveUntilField = 'effectiveUntil';
  static const String _targetDateField = 'targetDate';

  final JarTargetAmountPersistenceModel amount;
  final CalendarDate effectiveFrom;
  final CalendarDate? effectiveUntil;
  final CalendarDate? targetDate;

  const JarTargetPersistenceModel._({
    required this.amount,
    required this.effectiveFrom,
    required this.effectiveUntil,
    required this.targetDate,
  });

  factory JarTargetPersistenceModel.fromEntity(JarTarget target) {
    return JarTargetPersistenceModel._(
      amount: JarTargetAmountPersistenceModel.fromEntity(target.amount),
      effectiveFrom: target.effectiveFrom,
      effectiveUntil: target.effectiveUntil,
      targetDate: target.targetDate,
    );
  }

  factory JarTargetPersistenceModel.fromRecord(PersistenceRecord record) {
    final reader = PersistenceRecordReader(record);

    final amountRecord = reader.requiredMap(_amountField);

    final amount = withPersistenceRecordPath(
      _amountField,
      () => JarTargetAmountPersistenceModel.fromRecord(amountRecord),
    );

    return JarTargetPersistenceModel._(
      amount: amount,
      effectiveFrom: _readCalendarDate(
        reader: reader,
        field: _effectiveFromField,
      ),
      effectiveUntil: _readOptionalCalendarDate(
        reader: reader,
        field: _effectiveUntilField,
      ),
      targetDate: _readOptionalCalendarDate(
        reader: reader,
        field: _targetDateField,
      ),
    );
  }

  PersistenceRecord toRecord() {
    return <String, Object?>{
      _amountField: amount.toRecord(),
      _effectiveFromField: effectiveFrom.toString(),
      _effectiveUntilField: effectiveUntil?.toString(),
      _targetDateField: targetDate?.toString(),
    };
  }

  JarTarget toEntity() {
    try {
      return JarTarget(
        amount: amount.toEntity(),
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
        targetDate: targetDate,
      );
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted jar target violates current domain invariants.',
      );
    }
  }

  static CalendarDate _readCalendarDate({
    required PersistenceRecordReader reader,
    required String field,
  }) {
    final value = reader.requiredString(field);

    return _parseCalendarDate(value: value, field: field);
  }

  static CalendarDate? _readOptionalCalendarDate({
    required PersistenceRecordReader reader,
    required String field,
  }) {
    final value = reader.optionalString(field);

    if (value == null) {
      return null;
    }

    return _parseCalendarDate(value: value, field: field);
  }

  static CalendarDate _parseCalendarDate({
    required String value,
    required String field,
  }) {
    final match = RegExp(r'^(-?\d+)-(\d{2})-(\d{2})$').firstMatch(value);

    if (match == null) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a calendar date encoded as YYYY-MM-DD.',
      );
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);

    if (year == null || month == null || day == null) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a valid calendar date.',
      );
    }

    try {
      return CalendarDate(year, month, day);
    } on ArgumentError {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a valid calendar date.',
      );
    }
  }
}
