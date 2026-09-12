import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AssetNotFoundFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = AssetNotFoundFailure();

      // Then
      expect(failure.type, AssetNotFoundFailure.typeId);
    });
  });
}
