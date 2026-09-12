import 'package:axiom/src/core/failures/referenced_asset_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('ReferencedAssetNotFoundFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = ReferencedAssetNotFoundFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The referenced asset was not found.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = ReferencedAssetNotFoundFailure();

      // Then
      expect(failure.type, ReferencedAssetNotFoundFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = ReferencedAssetNotFoundFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
