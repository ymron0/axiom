@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/failures/invalid_rate_asset_semantics_failure.dart';
import 'package:test/test.dart';

void main() {
  group('InvalidRateAssetSemanticsFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = InvalidRateAssetSemanticsFailure(message: 'Reason');

      // Then
      expect(failure.type, InvalidRateAssetSemanticsFailure.typeId);
    });
  });
}
