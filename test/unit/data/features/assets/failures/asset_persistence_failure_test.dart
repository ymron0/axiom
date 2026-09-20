@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/assets/data/failures/asset_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AssetPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = AssetPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Asset persistence failed.';

      // When
      const failure = AssetPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = AssetPersistenceFailure();

      // Then
      expect(failure.type, AssetPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = AssetPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
