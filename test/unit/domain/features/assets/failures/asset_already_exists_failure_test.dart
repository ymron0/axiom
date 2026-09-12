import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AssetAlreadyExistsFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = AssetAlreadyExistsFailure();

      // Then
      expect(failure.type, AssetAlreadyExistsFailure.typeId);
    });
  });
}
