import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('UnexpectedPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = UnexpectedPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The persistence operation failed unexpectedly.';

      // When
      const failure = UnexpectedPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = UnexpectedPersistenceFailure();

      // Then
      expect(failure.type, UnexpectedPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = UnexpectedPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
