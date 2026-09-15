@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:test/test.dart';

Matcher _persistenceRecordException({
  required String field,
  required String reason,
}) {
  return isA<PersistenceRecordException>()
      .having((exception) => exception.field, 'field', field)
      .having((exception) => exception.reason, 'reason', reason);
}

void main() {
  group('PersistenceRecordReader', () {
    group('contains', () {
      test('returns true when the field exists', () {
        // Given
        const reader = PersistenceRecordReader({'name': 'Ada'});

        // When
        final result = reader.contains('name');

        // Then
        expect(result, isTrue);
      });

      test('returns true when the field exists with null', () {
        // Given
        const reader = PersistenceRecordReader({'name': null});

        // When
        final result = reader.contains('name');

        // Then
        expect(result, isTrue);
      });

      test('returns false when the field is absent', () {
        // Given
        const reader = PersistenceRecordReader({'name': 'Ada'});

        // When
        final result = reader.contains('missing');

        // Then
        expect(result, isFalse);
      });
    });

    group('requiredString', () {
      test('returns a valid String', () {
        // Given
        const reader = PersistenceRecordReader({'name': 'Ada'});

        // When
        final result = reader.requiredString('name');

        // Then
        expect(result, 'Ada');
      });

      test('throws when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When / Then
        expect(
          () => reader.requiredString('name'),
          throwsA(
            _persistenceRecordException(
              field: 'name',
              reason: 'Required field is missing.',
            ),
          ),
        );
      });

      test('throws when the value is null', () {
        // Given
        const reader = PersistenceRecordReader({'name': null});

        // When / Then
        expect(
          () => reader.requiredString('name'),
          throwsA(
            _persistenceRecordException(
              field: 'name',
              reason: 'Required field cannot be null.',
            ),
          ),
        );
      });

      test('throws when the value is not a String', () {
        // Given
        const reader = PersistenceRecordReader({'name': 42});

        // When / Then
        expect(
          () => reader.requiredString('name'),
          throwsA(
            _persistenceRecordException(
              field: 'name',
              reason: 'Expected String.',
            ),
          ),
        );
      });
    });

    group('optionalString', () {
      test('returns a valid String', () {
        // Given
        const reader = PersistenceRecordReader({'name': 'Ada'});

        // When
        final result = reader.optionalString('name');

        // Then
        expect(result, 'Ada');
      });

      test('returns null when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When
        final result = reader.optionalString('name');

        // Then
        expect(result, isNull);
      });

      test('returns null when the value is null', () {
        // Given
        const reader = PersistenceRecordReader({'name': null});

        // When
        final result = reader.optionalString('name');

        // Then
        expect(result, isNull);
      });

      test('throws when a non-null value is not a String', () {
        // Given
        const reader = PersistenceRecordReader({'name': 42});

        // When / Then
        expect(
          () => reader.optionalString('name'),
          throwsA(
            _persistenceRecordException(
              field: 'name',
              reason: 'Expected String or null.',
            ),
          ),
        );
      });
    });

    group('requiredInt', () {
      test('returns a valid int', () {
        // Given
        const reader = PersistenceRecordReader({'count': 42});

        // When
        final result = reader.requiredInt('count');

        // Then
        expect(result, 42);
      });

      test('throws when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When / Then
        expect(
          () => reader.requiredInt('count'),
          throwsA(
            _persistenceRecordException(
              field: 'count',
              reason: 'Required field is missing.',
            ),
          ),
        );
      });

      test('throws when the value is null', () {
        // Given
        const reader = PersistenceRecordReader({'count': null});

        // When / Then
        expect(
          () => reader.requiredInt('count'),
          throwsA(
            _persistenceRecordException(
              field: 'count',
              reason: 'Required field cannot be null.',
            ),
          ),
        );
      });

      test('throws when the value is the wrong type', () {
        // Given
        const reader = PersistenceRecordReader({'count': '42'});

        // When / Then
        expect(
          () => reader.requiredInt('count'),
          throwsA(
            _persistenceRecordException(
              field: 'count',
              reason: 'Expected int.',
            ),
          ),
        );
      });
    });

    group('optionalInt', () {
      test('returns a valid int', () {
        // Given
        const reader = PersistenceRecordReader({'count': 42});

        // When
        final result = reader.optionalInt('count');

        // Then
        expect(result, 42);
      });

      test('returns null when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When
        final result = reader.optionalInt('count');

        // Then
        expect(result, isNull);
      });

      test('returns null when the value is explicitly null', () {
        // Given
        const reader = PersistenceRecordReader({'count': null});

        // When
        final result = reader.optionalInt('count');

        // Then
        expect(result, isNull);
      });

      test('throws when the value is the wrong type', () {
        // Given
        const reader = PersistenceRecordReader({'count': '42'});

        // When / Then
        expect(
          () => reader.optionalInt('count'),
          throwsA(
            _persistenceRecordException(
              field: 'count',
              reason: 'Expected int or null.',
            ),
          ),
        );
      });
    });

    group('requiredBool', () {
      test('returns a valid bool', () {
        // Given
        const reader = PersistenceRecordReader({'enabled': true});

        // When
        final result = reader.requiredBool('enabled');

        // Then
        expect(result, isTrue);
      });

      test('throws when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When / Then
        expect(
          () => reader.requiredBool('enabled'),
          throwsA(
            _persistenceRecordException(
              field: 'enabled',
              reason: 'Required field is missing.',
            ),
          ),
        );
      });

      test('throws when the value is null', () {
        // Given
        const reader = PersistenceRecordReader({'enabled': null});

        // When / Then
        expect(
          () => reader.requiredBool('enabled'),
          throwsA(
            _persistenceRecordException(
              field: 'enabled',
              reason: 'Required field cannot be null.',
            ),
          ),
        );
      });

      test('throws when the value is the wrong type', () {
        // Given
        const reader = PersistenceRecordReader({'enabled': 'true'});

        // When / Then
        expect(
          () => reader.requiredBool('enabled'),
          throwsA(
            _persistenceRecordException(
              field: 'enabled',
              reason: 'Expected bool.',
            ),
          ),
        );
      });
    });

    group('optionalBool', () {
      test('returns a valid bool', () {
        // Given
        const reader = PersistenceRecordReader({'enabled': true});

        // When
        final result = reader.optionalBool('enabled');

        // Then
        expect(result, isTrue);
      });

      test('returns null when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When
        final result = reader.optionalBool('enabled');

        // Then
        expect(result, isNull);
      });

      test('returns null when the value is explicitly null', () {
        // Given
        const reader = PersistenceRecordReader({'enabled': null});

        // When
        final result = reader.optionalBool('enabled');

        // Then
        expect(result, isNull);
      });

      test('throws when the value is the wrong type', () {
        // Given
        const reader = PersistenceRecordReader({'enabled': 'true'});

        // When / Then
        expect(
          () => reader.optionalBool('enabled'),
          throwsA(
            _persistenceRecordException(
              field: 'enabled',
              reason: 'Expected bool or null.',
            ),
          ),
        );
      });
    });

    group('requiredMap', () {
      test('returns a valid map', () {
        // Given
        const reader = PersistenceRecordReader({
          'metadata': {'name': 'Ada'},
        });

        // When
        final result = reader.requiredMap('metadata');

        // Then
        expect(result, {'name': 'Ada'});
      });

      test('throws when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When / Then
        expect(
          () => reader.requiredMap('metadata'),
          throwsA(
            _persistenceRecordException(
              field: 'metadata',
              reason: 'Required field is missing.',
            ),
          ),
        );
      });

      test('throws when the value is null', () {
        // Given
        const reader = PersistenceRecordReader({'metadata': null});

        // When / Then
        expect(
          () => reader.requiredMap('metadata'),
          throwsA(
            _persistenceRecordException(
              field: 'metadata',
              reason: 'Required field cannot be null.',
            ),
          ),
        );
      });

      test('throws when the value is not a Map', () {
        // Given
        const reader = PersistenceRecordReader({'metadata': 'invalid'});

        // When / Then
        expect(
          () => reader.requiredMap('metadata'),
          throwsA(
            _persistenceRecordException(
              field: 'metadata',
              reason: 'Expected Map<String, Object?>.',
            ),
          ),
        );
      });

      test('throws when a nested map contains a non-String key', () {
        // Given
        final reader = PersistenceRecordReader({
          'metadata': <Object?, Object?>{1: 'invalid'},
        });

        // When / Then
        expect(
          () => reader.requiredMap('metadata'),
          throwsA(
            _persistenceRecordException(
              field: 'metadata',
              reason: 'Nested map contains a non-String key.',
            ),
          ),
        );
      });

      test('returns a defensive copy', () {
        // Given
        final sourceMap = <String, Object?>{'name': 'Ada'};
        final record = <String, Object?>{'metadata': sourceMap};
        final reader = PersistenceRecordReader(record);

        // When
        final result = reader.requiredMap('metadata');

        // Then
        expect(result, isNot(same(sourceMap)));
        expect(result, sourceMap);
      });

      test('does not mutate the source record when the returned map is mutated', () {
        // Given
        final sourceMap = <String, Object?>{'name': 'Ada'};
        final record = <String, Object?>{'metadata': sourceMap};
        final reader = PersistenceRecordReader(record);
        final result = reader.requiredMap('metadata');

        // When
        result['newField'] = true;

        // Then
        expect(sourceMap, {'name': 'Ada'});
        expect(record['metadata'], same(sourceMap));
      });
    });

    group('optionalMap', () {
      test('returns a valid map', () {
        // Given
        const reader = PersistenceRecordReader({
          'metadata': {'name': 'Ada'},
        });

        // When
        final result = reader.optionalMap('metadata');

        // Then
        expect(result, {'name': 'Ada'});
      });

      test('returns null when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When
        final result = reader.optionalMap('metadata');

        // Then
        expect(result, isNull);
      });

      test('returns null when the value is explicitly null', () {
        // Given
        const reader = PersistenceRecordReader({'metadata': null});

        // When
        final result = reader.optionalMap('metadata');

        // Then
        expect(result, isNull);
      });

      test('throws when a non-null value is not a Map', () {
        // Given
        const reader = PersistenceRecordReader({'metadata': 'invalid'});

        // When / Then
        expect(
          () => reader.optionalMap('metadata'),
          throwsA(
            _persistenceRecordException(
              field: 'metadata',
              reason: 'Expected Map<String, Object?> or null.',
            ),
          ),
        );
      });

      test('throws when a nested map contains a non-String key', () {
        // Given
        final reader = PersistenceRecordReader({
          'metadata': <Object?, Object?>{1: 'invalid'},
        });

        // When / Then
        expect(
          () => reader.optionalMap('metadata'),
          throwsA(
            _persistenceRecordException(
              field: 'metadata',
              reason: 'Nested map contains a non-String key.',
            ),
          ),
        );
      });

      test('returns a defensive copy', () {
        // Given
        final sourceMap = <String, Object?>{'name': 'Ada'};
        final record = <String, Object?>{'metadata': sourceMap};
        final reader = PersistenceRecordReader(record);

        // When
        final result = reader.optionalMap('metadata');

        // Then
        expect(result, isNot(same(sourceMap)));
        expect(result, sourceMap);
      });

      test('does not mutate the source record when the returned map is mutated', () {
        // Given
        final sourceMap = <String, Object?>{'name': 'Ada'};
        final record = <String, Object?>{'metadata': sourceMap};
        final reader = PersistenceRecordReader(record);
        final result = reader.optionalMap('metadata');

        // When
        result!['newField'] = true;

        // Then
        expect(sourceMap, {'name': 'Ada'});
        expect(record['metadata'], same(sourceMap));
      });
    });

    group('requiredList', () {
      test('returns a valid list', () {
        // Given
        const reader = PersistenceRecordReader({'values': [1, null, 'three']});

        // When
        final result = reader.requiredList('values');

        // Then
        expect(result, [1, null, 'three']);
      });

      test('throws when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When / Then
        expect(
          () => reader.requiredList('values'),
          throwsA(
            _persistenceRecordException(
              field: 'values',
              reason: 'Required field is missing.',
            ),
          ),
        );
      });

      test('throws when the value is null', () {
        // Given
        const reader = PersistenceRecordReader({'values': null});

        // When / Then
        expect(
          () => reader.requiredList('values'),
          throwsA(
            _persistenceRecordException(
              field: 'values',
              reason: 'Required field cannot be null.',
            ),
          ),
        );
      });

      test('throws when the value is the wrong type', () {
        // Given
        const reader = PersistenceRecordReader({'values': 'invalid'});

        // When / Then
        expect(
          () => reader.requiredList('values'),
          throwsA(
            _persistenceRecordException(
              field: 'values',
              reason: 'Expected List.',
            ),
          ),
        );
      });

      test('returns a defensive copy', () {
        // Given
        final sourceList = <Object?>[1, 2];
        final record = <String, Object?>{'values': sourceList};
        final reader = PersistenceRecordReader(record);

        // When
        final result = reader.requiredList('values');

        // Then
        expect(result, isNot(same(sourceList)));
        expect(result, sourceList);
      });

      test('does not mutate the source record when the returned list is mutated', () {
        // Given
        final sourceList = <Object?>[1, 2];
        final record = <String, Object?>{'values': sourceList};
        final reader = PersistenceRecordReader(record);
        final result = reader.requiredList('values');

        // When
        result.add(3);

        // Then
        expect(sourceList, [1, 2]);
        expect(record['values'], same(sourceList));
      });
    });

    group('optionalList', () {
      test('returns a valid list', () {
        // Given
        const reader = PersistenceRecordReader({'values': [1, null, 'three']});

        // When
        final result = reader.optionalList('values');

        // Then
        expect(result, [1, null, 'three']);
      });

      test('returns null when the field is missing', () {
        // Given
        const reader = PersistenceRecordReader({});

        // When
        final result = reader.optionalList('values');

        // Then
        expect(result, isNull);
      });

      test('returns null when the value is explicitly null', () {
        // Given
        const reader = PersistenceRecordReader({'values': null});

        // When
        final result = reader.optionalList('values');

        // Then
        expect(result, isNull);
      });

      test('throws when the value is the wrong type', () {
        // Given
        const reader = PersistenceRecordReader({'values': 'invalid'});

        // When / Then
        expect(
          () => reader.optionalList('values'),
          throwsA(
            _persistenceRecordException(
              field: 'values',
              reason: 'Expected List or null.',
            ),
          ),
        );
      });

      test('returns a defensive copy', () {
        // Given
        final sourceList = <Object?>[1, 2];
        final record = <String, Object?>{'values': sourceList};
        final reader = PersistenceRecordReader(record);

        // When
        final result = reader.optionalList('values');

        // Then
        expect(result, isNot(same(sourceList)));
        expect(result, sourceList);
      });

      test('does not mutate the source record when the returned list is mutated', () {
        // Given
        final sourceList = <Object?>[1, 2];
        final record = <String, Object?>{'values': sourceList};
        final reader = PersistenceRecordReader(record);
        final result = reader.optionalList('values');

        // When
        result!.add(3);

        // Then
        expect(sourceList, [1, 2]);
        expect(record['values'], same(sourceList));
      });
    });
  });
}
