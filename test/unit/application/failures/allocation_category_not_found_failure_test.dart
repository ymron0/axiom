@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AllocationCategoryNotFoundFailure', () {
    test('preserves its message and returns both typed getters', () {
      // Given
      const failure = AllocationCategoryNotFoundFailure(
        message: 'Allocation category was not found.',
      );

      // Then
      expect(failure.message, 'Allocation category was not found.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AllocationCategoryNotFoundFailure.typeId);
    });
  });
}
