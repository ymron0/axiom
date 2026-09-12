import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianNotFoundFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = CustodianNotFoundFailure(message: 'Not found.');

      expect(failure.message, 'Not found.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, CustodianNotFoundFailure.typeId);
    });
  });
}
