@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/merchants/data/failures/merchant_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = MerchantPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Merchant persistence failed.';

      // When
      const failure = MerchantPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = MerchantPersistenceFailure();

      // Then
      expect(failure.type, MerchantPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = MerchantPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
