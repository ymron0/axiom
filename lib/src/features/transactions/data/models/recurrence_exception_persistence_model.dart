import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_template_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_exception_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';

/// Persistence representation of a [RecurrenceException].
final class RecurrenceExceptionPersistenceModel {
  static const String _scheduledOnField = 'scheduledOn';
  static const String _kindField = 'kind';
  static const String _replacementOnField = 'replacementOn';
  static const String _replacementTemplateField = 'replacementTemplate';
  static const String _extendsSeriesField = 'extendsSeries';

  /// Original recurrence slot.
  final CalendarDate scheduledOn;

  /// Exception behavior.
  final RecurrenceExceptionKind kind;

  /// Optional replacement date.
  final CalendarDate? replacementOn;

  /// Optional replacement template.
  final TransactionTemplatePersistenceModel? replacementTemplate;

  /// Whether a skipped occurrence extends the finite recurrence.
  final bool extendsSeries;

  /// Creates a persistence representation.
  const RecurrenceExceptionPersistenceModel({
    required this.scheduledOn,
    required this.kind,
    required this.replacementOn,
    required this.replacementTemplate,
    this.extendsSeries = false,
  });

  /// Creates the persistence model from a domain value.
  factory RecurrenceExceptionPersistenceModel.fromEntity(
    RecurrenceException exception,
  ) {
    return RecurrenceExceptionPersistenceModel(
      scheduledOn: exception.scheduledOn,
      kind: exception.kind,
      replacementOn: exception.replacementOn,
      replacementTemplate: exception.replacementTemplate == null
          ? null
          : TransactionTemplatePersistenceModel.fromEntity(
              exception.replacementTemplate!,
            ),
      extendsSeries: exception.extendsSeries,
    );
  }

  /// Reconstructs a persistence model from stored data.
  factory RecurrenceExceptionPersistenceModel.fromRecord(
    PersistenceRecord record, {
    required String path,
  }) {
    return withPersistenceRecordPath(path, () {
      final reader = PersistenceRecordReader(record);

      final rawReplacementTemplate = reader.optionalMap(
        _replacementTemplateField,
      );

      return RecurrenceExceptionPersistenceModel(
        scheduledOn: readCalendarDate(
          reader.requiredString(_scheduledOnField),
          field: _scheduledOnField,
        ),
        kind: readPersistenceEnum(
          reader: reader,
          field: _kindField,
          values: RecurrenceExceptionKind.values,
        ),
        replacementOn: readOptionalCalendarDate(reader, _replacementOnField),
        replacementTemplate: rawReplacementTemplate == null
            ? null
            : TransactionTemplatePersistenceModel.fromRecord(
                rawReplacementTemplate,
                path: '$path.$_replacementTemplateField',
              ),
        extendsSeries: reader.contains(_extendsSeriesField)
            ? reader.requiredBool(_extendsSeriesField)
            : false,
      );
    });
  }

  /// Converts the model to its primitive persistence record.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _scheduledOnField: scheduledOn.toString(),
      _kindField: kind.name,
      _replacementOnField: replacementOn?.toString(),
      _replacementTemplateField: replacementTemplate?.toRecord(),
      if (extendsSeries) _extendsSeriesField: true,
    };
  }

  /// Reconstructs the domain value.
  RecurrenceException toEntity() {
    return RecurrenceException(
      scheduledOn: scheduledOn,
      kind: kind,
      replacementOn: replacementOn,
      replacementTemplate: replacementTemplate?.toEntity(),
      extendsSeries: extendsSeries,
    );
  }
}
