import 'package:axiom/src/features/custodians/domain/failures/custodian_in_use_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianInUseFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = CustodianInUseFailure(message: 'Custodian is in use.');

      expect(failure.message, 'Custodian is in use.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, CustodianInUseFailure.typeId);
    });
  });
}
