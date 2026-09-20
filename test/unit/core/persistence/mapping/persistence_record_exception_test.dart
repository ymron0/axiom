@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:test/test.dart';

void main() {
  group('PersistenceRecordException', () {
    test('preserves the reason', () {
      // Given
      const reason = 'The persisted value is invalid.';

      // When
      const exception = PersistenceRecordException(reason: reason);

      // Then
      expect(exception.reason, reason);
    });

    test('preserves the provided field', () {
      // Given
      const field = 'amount';

      // When
      const exception = PersistenceRecordException(
        reason: 'The persisted value is invalid.',
        field: field,
      );

      // Then
      expect(exception.field, field);
    });

    test('defaults field to null', () {
      // Given
      const exception = PersistenceRecordException(
        reason: 'The persisted value is invalid.',
      );

      // Then
      expect(exception.field, isNull);
    });

    test('includes the field in toString when provided', () {
      // Given
      const exception = PersistenceRecordException(
        reason: 'The persisted value is invalid.',
        field: 'amount',
      );

      // When
      final description = exception.toString();

      // Then
      expect(
        description,
        'PersistenceRecordException(amount): The persisted value is invalid.',
      );
    });

    test('omits the field from toString when absent', () {
      // Given
      const exception = PersistenceRecordException(
        reason: 'The persisted value is invalid.',
      );

      // When
      final description = exception.toString();

      // Then
      expect(
        description,
        'PersistenceRecordException: The persisted value is invalid.',
      );
    });

    test('implements Exception', () {
      // Given
      const exception = PersistenceRecordException(
        reason: 'The persisted value is invalid.',
      );

      // Then
      expect(exception, isA<Exception>());
    });
  });
}
