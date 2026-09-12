import 'package:axiom/src/features/custodians/domain/failures/custodian_already_active_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianAlreadyActiveFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = CustodianAlreadyActiveFailure(message: 'Already active.');

      expect(failure.message, 'Already active.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, CustodianAlreadyActiveFailure.typeId);
    });
  });
}
