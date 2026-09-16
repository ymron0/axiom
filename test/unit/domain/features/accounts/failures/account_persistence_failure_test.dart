@Tags(['domain'])
library;

import 'package:axiom/src/features/accounts/domain/failures/account_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = AccountPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Account persistence failed.';

      // When
      const failure = AccountPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = AccountPersistenceFailure();

      // Then
      expect(failure.type, AccountPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = AccountPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
