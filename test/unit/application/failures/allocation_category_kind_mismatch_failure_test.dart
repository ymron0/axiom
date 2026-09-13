import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AllocationCategoryKindMismatchFailure', () {
    test('preserves its message and returns both typed getters', () {
      // Given
      const failure = AllocationCategoryKindMismatchFailure(
        message: 'Allocation category kinds do not match.',
      );

      // Then
      expect(failure.message, 'Allocation category kinds do not match.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AllocationCategoryKindMismatchFailure.typeId);
    });
  });
}
