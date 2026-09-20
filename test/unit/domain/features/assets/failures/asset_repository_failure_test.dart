import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AssetRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = AssetRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, AssetRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
