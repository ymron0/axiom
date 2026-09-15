@Tags(['core', 'persistence'])
library;

import 'package:axiom/src/core/persistence/failures/corrupt_persistence_record_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CorruptPersistenceRecordFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = CorruptPersistenceRecordFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The persisted record is corrupt.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = CorruptPersistenceRecordFailure();

      // Then
      expect(failure.type, CorruptPersistenceRecordFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = CorruptPersistenceRecordFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
