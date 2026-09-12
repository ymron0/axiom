import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RateNotFoundFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = RateNotFoundFailure();

      // Then
      expect(failure.type, RateNotFoundFailure.typeId);
    });
  });
}
