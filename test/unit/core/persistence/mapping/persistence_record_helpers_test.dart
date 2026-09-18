@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

enum _TestStatus { active, archived }

Matcher _persistenceRecordException({
  required String? field,
  required String reason,
}) {
  return isA<PersistenceRecordException>()
      .having((exception) => exception.field, 'field', field)
      .having((exception) => exception.reason, 'reason', reason);
}

void main() {
  group('persistence record helpers', () {
    group('readPositivePersistenceInt', () {
      test('returns a positive integer', () {
        // Given
        const reader = PersistenceRecordReader({'version': 3});

        // When
        final result = readPositivePersistenceInt(reader, 'version');

        // Then
        expect(result, 3);
      });

      test('throws when the value is zero', () {
        // Given
        const reader = PersistenceRecordReader({'version': 0});

        // When / Then
        expect(
          () => readPositivePersistenceInt(reader, 'version'),
          throwsA(
            _persistenceRecordException(
              field: 'version',
              reason: 'Expected an integer greater than zero.',
            ),
          ),
        );
      });

      test('throws when the value is negative', () {
        // Given
        const reader = PersistenceRecordReader({'version': -1});

        // When / Then
        expect(
          () => readPositivePersistenceInt(reader, 'version'),
          throwsA(
            _persistenceRecordException(
              field: 'version',
              reason: 'Expected an integer greater than zero.',
            ),
          ),
        );
      });
    });

    group('readPersistenceEnum', () {
      test('returns the enum value matching its persisted name', () {
        // Given
        const reader = PersistenceRecordReader({'status': 'archived'});

        // When
        final result = readPersistenceEnum<_TestStatus>(
          reader: reader,
          field: 'status',
          values: _TestStatus.values,
        );

        // Then
        expect(result, _TestStatus.archived);
      });

      test('throws a persistence exception for an unsupported enum name', () {
        // Given
        const reader = PersistenceRecordReader({'status': 'deleted'});

        // When / Then
        expect(
          () => readPersistenceEnum<_TestStatus>(
            reader: reader,
            field: 'status',
            values: _TestStatus.values,
          ),
          throwsA(
            _persistenceRecordException(
              field: 'status',
              reason: 'Stored enum value is not supported.',
            ),
          ),
        );
      });

      test('preserves a reader exception for a missing enum field', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When / Then
        expect(
          () => readPersistenceEnum<_TestStatus>(
            reader: reader,
            field: 'status',
            values: _TestStatus.values,
          ),
          throwsA(
            _persistenceRecordException(
              field: 'status',
              reason: 'Required field is missing.',
            ),
          ),
        );
      });
    });

    group('readPersistenceDateTime', () {
      test('returns a parsed UTC timestamp', () {
        // Given
        const reader = PersistenceRecordReader({
          'createdAt': '2026-09-16T10:20:30.000Z',
        });

        // When
        final result = readPersistenceDateTime(reader, 'createdAt');

        // Then
        expect(result, DateTime.utc(2026, 9, 16, 10, 20, 30));
        expect(result.isUtc, isTrue);
      });

      test('throws for an invalid timestamp', () {
        // Given
        const reader = PersistenceRecordReader({'createdAt': 'not-a-date'});

        // When / Then
        expect(
          () => readPersistenceDateTime(reader, 'createdAt'),
          throwsA(
            _persistenceRecordException(
              field: 'createdAt',
              reason: 'Expected a UTC ISO-8601 timestamp.',
            ),
          ),
        );
      });

      test('throws for a timestamp without an explicit UTC designator', () {
        // Given
        const reader = PersistenceRecordReader({
          'createdAt': '2026-09-16T10:20:30',
        });

        // When / Then
        expect(
          () => readPersistenceDateTime(reader, 'createdAt'),
          throwsA(
            _persistenceRecordException(
              field: 'createdAt',
              reason: 'Expected a UTC ISO-8601 timestamp.',
            ),
          ),
        );
      });

      test('preserves a reader exception for a null timestamp', () {
        // Given
        const reader = PersistenceRecordReader({'createdAt': null});

        // When / Then
        expect(
          () => readPersistenceDateTime(reader, 'createdAt'),
          throwsA(
            _persistenceRecordException(
              field: 'createdAt',
              reason: 'Required field cannot be null.',
            ),
          ),
        );
      });
    });

    group('readOptionalUtcDateTime', () {
      test('returns null for an absent timestamp', () {
        const reader = PersistenceRecordReader({});

        expect(readOptionalUtcDateTime(reader, 'archivedAt'), isNull);
      });

      test('returns a parsed UTC timestamp', () {
        const reader = PersistenceRecordReader({
          'archivedAt': '2026-09-16T10:20:30.000Z',
        });

        final result = readOptionalUtcDateTime(reader, 'archivedAt');

        expect(result, DateTime.utc(2026, 9, 16, 10, 20, 30));
        expect(result!.isUtc, isTrue);
      });

      test('throws for a timestamp without an explicit UTC designator', () {
        const reader = PersistenceRecordReader({
          'archivedAt': '2026-09-16T10:20:30',
        });

        expect(
          () => readOptionalUtcDateTime(reader, 'archivedAt'),
          throwsA(
            _persistenceRecordException(
              field: 'archivedAt',
              reason: 'Expected a UTC ISO-8601 timestamp.',
            ),
          ),
        );
      });
    });

    group('readOptionalCalendarDate', () {
      test('returns null for a null date', () {
        const reader = PersistenceRecordReader({'effectiveUntil': null});

        expect(readOptionalCalendarDate(reader, 'effectiveUntil'), isNull);
      });

      test('returns a parsed calendar date', () {
        const reader = PersistenceRecordReader({
          'effectiveUntil': '2026-09-16',
        });

        expect(
          readOptionalCalendarDate(reader, 'effectiveUntil'),
          CalendarDate(2026, 9, 16),
        );
      });

      test('throws for a malformed calendar date', () {
        const reader = PersistenceRecordReader({
          'effectiveUntil': '2026-9-16',
        });

        expect(
          () => readOptionalCalendarDate(reader, 'effectiveUntil'),
          throwsA(
            _persistenceRecordException(
              field: 'effectiveUntil',
              reason: 'Expected a calendar date in YYYY-MM-DD format.',
            ),
          ),
        );
      });

      test('throws for invalid calendar components', () {
        const reader = PersistenceRecordReader({
          'effectiveUntil': '2026-02-30',
        });

        expect(
          () => readOptionalCalendarDate(reader, 'effectiveUntil'),
          throwsA(
            _persistenceRecordException(
              field: 'effectiveUntil',
              reason: 'Expected a valid calendar date.',
            ),
          ),
        );
      });
    });

    group('readCalendarDate', () {
      test('returns a parsed calendar date', () {
        expect(
          readCalendarDate('2026-09-16', field: 'startsOn'),
          CalendarDate(2026, 9, 16),
        );
      });

      test('throws for a timestamp representation', () {
        expect(
          () => readCalendarDate(
            '2026-09-16T00:00:00.000Z',
            field: 'startsOn',
          ),
          throwsA(
            _persistenceRecordException(
              field: 'startsOn',
              reason: 'Expected a calendar date in YYYY-MM-DD format.',
            ),
          ),
        );
      });

      test('throws for invalid calendar components', () {
        expect(
          () => readCalendarDate('2026-13-01', field: 'startsOn'),
          throwsA(
            _persistenceRecordException(
              field: 'startsOn',
              reason: 'Expected a valid calendar date.',
            ),
          ),
        );
      });
    });

    group('readPersistenceDecimal', () {
      test('returns a decimal parsed from its persisted string', () {
        // Given
        const reader = PersistenceRecordReader({'amount': '123.4500'});

        // When
        final result = readPersistenceDecimal(reader, 'amount');

        // Then
        expect(result, Decimal.parse('123.4500'));
      });

      test('throws for an invalid decimal string', () {
        // Given
        const reader = PersistenceRecordReader({'amount': 'not-a-decimal'});

        // When / Then
        expect(
          () => readPersistenceDecimal(reader, 'amount'),
          throwsA(
            _persistenceRecordException(
              field: 'amount',
              reason: 'Expected a valid decimal string.',
            ),
          ),
        );
      });

      test('preserves a reader exception for a non-string decimal', () {
        // Given
        const reader = PersistenceRecordReader({'amount': 123.45});

        // When / Then
        expect(
          () => readPersistenceDecimal(reader, 'amount'),
          throwsA(
            _persistenceRecordException(
              field: 'amount',
              reason: 'Expected String.',
            ),
          ),
        );
      });
    });

    group('persistenceRecordFromListValue', () {
      test('converts a map into a persistence record', () {
        // Given
        final value = <Object, Object?>{
          'id': 'transaction-1',
          'amount': '12.50',
        };

        // When
        final result = persistenceRecordFromListValue(
          value,
          field: 'splits',
        );

        // Then
        expect(result, <String, Object?>{
          'id': 'transaction-1',
          'amount': '12.50',
        });
      });

      test('throws when the list element is not a map', () {
        // Given
        const value = 'not-a-map';

        // When / Then
        expect(
          () => persistenceRecordFromListValue(value, field: 'splits'),
          throwsA(
            _persistenceRecordException(
              field: 'splits',
              reason: 'Expected Map<String, Object?>.',
            ),
          ),
        );
      });

      test('throws when the nested map contains a non-string key', () {
        // Given
        final value = <Object, Object?>{1: 'invalid'};

        // When / Then
        expect(
          () => persistenceRecordFromListValue(value, field: 'splits'),
          throwsA(
            _persistenceRecordException(
              field: 'splits',
              reason: 'Nested map contains a non-String key.',
            ),
          ),
        );
      });
    });

    group('withPersistenceRecordPath', () {
      test('returns the operation result when no exception is thrown', () {
        // Given
        const operation = 42;

        // When
        final result = withPersistenceRecordPath('splits[0]', () => operation);

        // Then
        expect(result, operation);
      });

      test('prefixes the path of a field-specific persistence exception', () {
        // Given
        const error = PersistenceRecordException(
          field: 'amount',
          reason: 'Expected a valid decimal string.',
        );

        // When / Then
        expect(
          () => withPersistenceRecordPath('splits[0]', () => throw error),
          throwsA(
            _persistenceRecordException(
              field: 'splits[0].amount',
              reason: 'Expected a valid decimal string.',
            ),
          ),
        );
      });

      test('uses the path when a persistence exception has no field', () {
        // Given
        const error = PersistenceRecordException(
          reason: 'The nested record is invalid.',
        );

        // When / Then
        expect(
          () => withPersistenceRecordPath('splits[0]', () => throw error),
          throwsA(
            _persistenceRecordException(
              field: 'splits[0]',
              reason: 'The nested record is invalid.',
            ),
          ),
        );
      });

      test('does not catch unrelated exceptions', () {
        // Given
        final error = StateError('unexpected failure');

        // When / Then
        expect(
          () => withPersistenceRecordPath('splits[0]', () => throw error),
          throwsA(same(error)),
        );
      });
    });
  });
}
