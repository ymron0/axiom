import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/transactions/data/models/recurrence_exception_persistence_model.dart';
import 'package:axiom/src/features/transactions/data/models/recurrence_rule_persistence_model.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_template_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';

/// Persistence representation of a [TransactionSeries].
///
/// The model owns the complete translation boundary between recurring
/// transaction domain values and primitive Sembast records.
///
/// ## Identity
///
/// [TransactionSeries.id] is represented by the Sembast record key and is not
/// duplicated inside the persisted record.
///
/// ## Embedded values
///
/// A series persists its complete definition:
///
/// - default transaction template;
/// - recurrence rule;
/// - recurrence termination conditions;
/// - amount-based termination configuration;
/// - recurrence exceptions; and
/// - replacement transaction templates.
///
/// Generated transactions are deliberately not stored here.
///
/// ## Lifecycle
///
/// Active and archived series remain persisted.
///
/// Deleted series do not. A persisted record containing a non-null
/// `deletedAt` is therefore invalid persisted state.
///
/// ## Failure behavior
///
/// Persisted data is treated as untrusted.
///
/// Structural errors and values that can no longer satisfy current domain
/// invariants are translated into [PersistenceRecordException].
final class TransactionSeriesPersistenceModel {
  static const String _templateField = 'template';
  static const String _recurrenceRuleField = 'recurrenceRule';
  static const String _exceptionsField = 'exceptions';
  static const String _archivedAtField = 'archivedAt';
  static const String _deletedAtField = 'deletedAt';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Series identity represented by the Sembast record key.
  final String id;

  /// Persisted default transaction template.
  final TransactionTemplatePersistenceModel template;

  /// Persisted recurrence definition.
  final RecurrenceRulePersistenceModel recurrenceRule;

  /// Persisted recurrence exceptions.
  final List<RecurrenceExceptionPersistenceModel> exceptions;

  /// Optional archival timestamp.
  final DateTime? archivedAt;

  /// Optional deletion timestamp.
  ///
  /// Valid persisted records always contain `null`.
  final DateTime? deletedAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Most recent modification timestamp.
  final DateTime modifiedAt;

  /// Domain entity class version.
  final int entityVersion;

  TransactionSeriesPersistenceModel._({
    required this.id,
    required this.template,
    required this.recurrenceRule,
    required List<RecurrenceExceptionPersistenceModel> exceptions,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.modifiedAt,
    required this.entityVersion,
  }) : exceptions = List.unmodifiable(exceptions);

  /// Creates a persistence representation of an active or archived [series].
  ///
  /// Deleted series cannot be persisted because repository deletion is
  /// physical.
  factory TransactionSeriesPersistenceModel.fromEntity(
    TransactionSeries series,
  ) {
    if (series.isDeleted) {
      throw StateError(
        'Deleted transaction series cannot be represented as persisted '
        'transaction-series records.',
      );
    }

    return TransactionSeriesPersistenceModel._(
      id: series.id.value,
      template: TransactionTemplatePersistenceModel.fromEntity(
        series.template,
      ),
      recurrenceRule: RecurrenceRulePersistenceModel.fromEntity(
        series.recurrenceRule,
      ),
      exceptions: series.exceptions
          .map(RecurrenceExceptionPersistenceModel.fromEntity)
          .toList(growable: false),
      archivedAt: series.archivedAt,
      deletedAt: null,
      createdAt: series.createdAt,
      modifiedAt: series.modifiedAt,
      entityVersion: series.entityVersion,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [recordKey] is the authoritative transaction-series identity.
  factory TransactionSeriesPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);
    final rawExceptions = reader.requiredList(_exceptionsField);

    return TransactionSeriesPersistenceModel._(
      id: recordKey,
      template: TransactionTemplatePersistenceModel.fromRecord(
        reader.requiredMap(_templateField),
        path: _templateField,
      ),
      recurrenceRule: RecurrenceRulePersistenceModel.fromRecord(
        reader.requiredMap(_recurrenceRuleField),
        path: _recurrenceRuleField,
      ),
      exceptions: <RecurrenceExceptionPersistenceModel>[
        for (var index = 0; index < rawExceptions.length; index++)
          RecurrenceExceptionPersistenceModel.fromRecord(
            persistenceRecordFromListValue(
              rawExceptions[index],
              field: '$_exceptionsField[$index]',
            ),
            path: '$_exceptionsField[$index]',
          ),
      ],
      archivedAt: readOptionalUtcDateTime(reader, _archivedAtField),
      deletedAt: readOptionalUtcDateTime(reader, _deletedAtField),
      createdAt: readPersistenceDateTime(reader, _createdAtField),
      modifiedAt: readPersistenceDateTime(reader, _modifiedAtField),
      entityVersion: readPositivePersistenceInt(reader, _entityVersionField),
    );
  }

  /// Converts this model to the primitive Sembast record representation.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _templateField: template.toRecord(),
      _recurrenceRuleField: recurrenceRule.toRecord(),
      _exceptionsField: exceptions
          .map((exception) => exception.toRecord())
          .toList(growable: false),
      _archivedAtField: archivedAt?.toUtc().toIso8601String(),
      _deletedAtField: deletedAt?.toUtc().toIso8601String(),
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }

  /// Reconstructs the domain [TransactionSeries].
  ///
  /// All current domain invariants are intentionally revalidated.
  TransactionSeries toEntity() {
    if (deletedAt != null) {
      throw const PersistenceRecordException(
        field: _deletedAtField,
        reason:
            'Deleted transaction series must not remain in persistent '
            'transaction-series storage.',
      );
    }

    try {
      return TransactionSeries(
        id: TransactionSeriesId.fromString(id),
        template: template.toEntity(),
        recurrenceRule: recurrenceRule.toEntity(),
        exceptions: exceptions
            .map((exception) => exception.toEntity())
            .toList(growable: false),
        archivedAt: archivedAt,
        deletedAt: null,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        entityVersion: entityVersion,
      );
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason:
            'Persisted transaction series violates current domain invariants.',
      );
      // coverage:ignore-start
    } on FormatException {
      throw const PersistenceRecordException(
        reason:
            'Persisted transaction series contains an invalid domain value.',
      );
    }
    // coverage:ignore-end
  }
}
