@Tags(['domain'])
library;

import 'package:axiom/src/features/custodians/domain/failures/custodian_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = CustodianPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Custodian persistence failed.';

      // When
      const failure = CustodianPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = CustodianPersistenceFailure();

      // Then
      expect(failure.type, CustodianPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = CustodianPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
