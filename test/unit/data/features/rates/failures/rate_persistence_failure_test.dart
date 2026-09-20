@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/rates/data/failures/rate_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RatePersistenceFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = RatePersistenceFailure();

      // Then
      expect(failure.type, RatePersistenceFailure.typeId);
    });
  });
}
