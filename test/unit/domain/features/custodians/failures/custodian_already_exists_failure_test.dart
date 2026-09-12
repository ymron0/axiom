import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianAlreadyExistsFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = CustodianAlreadyExistsFailure(
        message: 'Already exists.',
      );

      expect(failure.message, 'Already exists.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, CustodianAlreadyExistsFailure.typeId);
    });
  });
}
