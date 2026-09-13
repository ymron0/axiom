import 'package:axiom/src/application/failures/allocation_jar_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AllocationJarNotFoundFailure', () {
    test('preserves its message and returns both typed getters', () {
      // Given
      const failure = AllocationJarNotFoundFailure(
        message: 'Allocation jar was not found.',
      );

      // Then
      expect(failure.message, 'Allocation jar was not found.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AllocationJarNotFoundFailure.typeId);
    });
  });
}
