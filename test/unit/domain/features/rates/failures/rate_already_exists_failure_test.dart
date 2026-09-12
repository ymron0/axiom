import 'package:axiom/src/features/rates/domain/failures/rate_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RateAlreadyExistsFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = RateAlreadyExistsFailure();

      // Then
      expect(failure.type, RateAlreadyExistsFailure.typeId);
    });
  });
}
