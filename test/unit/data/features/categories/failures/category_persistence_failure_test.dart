@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/categories/data/failures/category_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = CategoryPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Category persistence failed.';

      // When
      const failure = CategoryPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = CategoryPersistenceFailure();

      // Then
      expect(failure.type, CategoryPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = CategoryPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
