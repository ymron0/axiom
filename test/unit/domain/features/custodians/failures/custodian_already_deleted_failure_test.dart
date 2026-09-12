import 'package:axiom/src/features/custodians/domain/failures/custodian_already_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianAlreadyDeletedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = CustodianAlreadyDeletedFailure(
        message: 'Already deleted.',
      );

      expect(failure.message, 'Already deleted.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, CustodianAlreadyDeletedFailure.typeId);
    });
  });
}
