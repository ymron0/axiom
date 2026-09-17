@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/failures/unsupported_rate_synchronization_asset_failure.dart';
import 'package:test/test.dart';

void main() {
  group('UnsupportedRateSynchronizationAssetFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = UnsupportedRateSynchronizationAssetFailure(
        message: 'Reason',
      );

      // Then
      expect(failure.type, UnsupportedRateSynchronizationAssetFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = UnsupportedRateSynchronizationAssetFailure(
        message: 'Reason',
      );

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
