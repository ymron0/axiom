@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/failures/rate_source_acquisition_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RateSourceAcquisitionFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = RateSourceAcquisitionFailure(message: 'Network error');

      // Then
      expect(failure.type, RateSourceAcquisitionFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = RateSourceAcquisitionFailure(message: 'Network error');

      // Then
      expect(failure.failureOrNull, same(failure));
    });

    test('retains the provided error message', () {
      // Given
      const failure = RateSourceAcquisitionFailure(
        message: 'Provider timed out',
      );

      // Then
      expect(failure.message, 'Provider timed out');
    });

    test('supports value equality and hashing', () {
      // Given
      const failure1 = RateSourceAcquisitionFailure(
        message: 'Failed to acquire',
      );
      const failure2 = RateSourceAcquisitionFailure(
        message: 'Failed to acquire',
      );
      const failure3 = RateSourceAcquisitionFailure(message: 'Different error');

      // Then
      expect(failure1, equals(failure2));
      expect(failure1.hashCode, equals(failure2.hashCode));
      expect(failure1, isNot(equals(failure3)));
    });
  });
}
