import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RateRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = RateRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, RateRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
