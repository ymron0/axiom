import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:decimal/decimal.dart';

/// Reads a positive integer persistence field.
int readPositivePersistenceInt(PersistenceRecordReader reader, String field) {
  final value = reader.requiredInt(field);

  if (value <= 0) {
    throw PersistenceRecordException(
      field: field,
      reason: 'Expected an integer greater than zero.',
    );
  }

  return value;
}

/// Reads an enum encoded using [Enum.name].
T readPersistenceEnum<T extends Enum>({
  required PersistenceRecordReader reader,
  required String field,
  required List<T> values,
}) {
  final value = reader.requiredString(field);

  try {
    return values.byName(value);
  } on ArgumentError {
    throw PersistenceRecordException(
      field: field,
      reason: 'Stored enum value is not supported.',
    );
  }
}

/// Reads a UTC ISO-8601 timestamp.
DateTime readPersistenceDateTime(PersistenceRecordReader reader, String field) {
  final value = reader.requiredString(field);

  try {
    final parsed = DateTime.parse(value);

    if (!parsed.isUtc) {
      throw const FormatException();
    }

    return parsed.toUtc();
  } on FormatException {
    throw PersistenceRecordException(
      field: field,
      reason: 'Expected a UTC ISO-8601 timestamp.',
    );
  }
}

/// Reads a decimal encoded as a base-10 string.
Decimal readPersistenceDecimal(PersistenceRecordReader reader, String field) {
  final value = reader.requiredString(field);

  try {
    return Decimal.parse(value);
  } on FormatException {
    throw PersistenceRecordException(
      field: field,
      reason: 'Expected a valid decimal string.',
    );
  }
}

/// Converts one raw list element into a validated persistence record.
PersistenceRecord persistenceRecordFromListValue(
  Object? value, {
  required String field,
}) {
  if (value is! Map) {
    throw PersistenceRecordException(
      field: field,
      reason: 'Expected Map<String, Object?>.',
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

/// Prefixes nested persistence-reader failures with their aggregate path.
T withPersistenceRecordPath<T>(String path, T Function() operation) {
  try {
    return operation();
  } on PersistenceRecordException catch (error) {
    final field = error.field;

    throw PersistenceRecordException(
      field: field == null ? path : '$path.$field',
      reason: error.reason,
    );
  }
}
