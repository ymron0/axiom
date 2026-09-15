import 'persistence_record.dart';
import 'persistence_record_exception.dart';

/// Provides validated access to fields stored in a [PersistenceRecord].
///
/// Persisted data is treated as untrusted input. Feature-specific persistence
/// mappers should use this reader instead of directly casting map values.
///
/// For example, prefer:
///
/// ```dart
/// final name = reader.requiredString('name');
/// ```
///
/// over:
///
/// ```dart
/// final name = record['name'] as String;
/// ```
///
/// Invalid or missing fields produce [PersistenceRecordException], which is
/// translated into a typed persistence failure by the mapping infrastructure.
final class PersistenceRecordReader {
  const PersistenceRecordReader(this._record);

  final PersistenceRecord _record;

  /// Whether the record contains [field].
  bool contains(String field) => _record.containsKey(field);

  /// Reads a required [String].
  ///
  /// Throws [PersistenceRecordException] if the field is absent, null, or is
  /// not a [String].
  String requiredString(String field) {
    final value = _requiredValue(field);

    if (value is! String) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected String.',
      );
    }

    return value;
  }

  /// Reads an optional [String].
  ///
  /// Returns null when the field is absent or contains null.
  ///
  /// Throws [PersistenceRecordException] if a non-null value is not a
  /// [String].
  String? optionalString(String field) {
    final value = _record[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected String or null.',
      );
    }

    return value;
  }

  /// Reads a required [int].
  int requiredInt(String field) {
    final value = _requiredValue(field);

    if (value is! int) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected int.',
      );
    }

    return value;
  }

  /// Reads an optional [int].
  int? optionalInt(String field) {
    final value = _record[field];

    if (value == null) {
      return null;
    }

    if (value is! int) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected int or null.',
      );
    }

    return value;
  }

  /// Reads a required [bool].
  bool requiredBool(String field) {
    final value = _requiredValue(field);

    if (value is! bool) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected bool.',
      );
    }

    return value;
  }

  /// Reads an optional [bool].
  bool? optionalBool(String field) {
    final value = _record[field];

    if (value == null) {
      return null;
    }

    if (value is! bool) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected bool or null.',
      );
    }

    return value;
  }

  /// Reads a required nested record.
  ///
  /// A defensive copy is returned so callers cannot modify the persisted
  /// representation through the reader.
  PersistenceRecord requiredMap(String field) {
    final value = _requiredValue(field);

    return _asMap(
      field: field,
      value: value,
      nullable: false,
    )!;
  }

  /// Reads an optional nested record.
  ///
  /// A defensive copy is returned when a value exists.
  PersistenceRecord? optionalMap(String field) {
    final value = _record[field];

    if (value == null) {
      return null;
    }

    return _asMap(
      field: field,
      value: value,
      nullable: true,
    );
  }

  /// Reads a required list.
  ///
  /// A defensive copy is returned.
  List<Object?> requiredList(String field) {
    final value = _requiredValue(field);

    if (value is! List) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected List.',
      );
    }

    return List<Object?>.from(value);
  }

  /// Reads an optional list.
  ///
  /// A defensive copy is returned when a value exists.
  List<Object?>? optionalList(String field) {
    final value = _record[field];

    if (value == null) {
      return null;
    }

    if (value is! List) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected List or null.',
      );
    }

    return List<Object?>.from(value);
  }

  Object _requiredValue(String field) {
    if (!_record.containsKey(field)) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Required field is missing.',
      );
    }

    final value = _record[field];

    if (value == null) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Required field cannot be null.',
      );
    }

    return value;
  }

  PersistenceRecord? _asMap({
    required String field,
    required Object value,
    required bool nullable,
  }) {
    if (value is! Map) {
      throw PersistenceRecordException(
        field: field,
        reason: nullable
            ? 'Expected Map<String, Object?> or null.'
            : 'Expected Map<String, Object?>.',
      );
    }

    for (final key in value.keys) {
      if (key is! String) {
        throw PersistenceRecordException(
          field: field,
          reason: 'Nested map contains a non-String key.',
        );
      }
    }

    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: entry.value as Object?,
    };
  }
}