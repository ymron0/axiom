@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/jars/data/failures/jar_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = JarPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Jar persistence failed.';

      // When
      const failure = JarPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = JarPersistenceFailure();

      // Then
      expect(failure.type, JarPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = JarPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
