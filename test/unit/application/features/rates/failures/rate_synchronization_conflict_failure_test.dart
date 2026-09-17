@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/failures/rate_synchronization_conflict_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RateSynchronizationConflictFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = RateSynchronizationConflictFailure(message: 'Reason');

      // Then
      expect(failure.type, RateSynchronizationConflictFailure.typeId);
    });
  });
}
