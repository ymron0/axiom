import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountAlreadyDeletedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = AccountAlreadyDeletedFailure(
        message: 'Already deleted.',
      );

      expect(failure.message, 'Already deleted.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AccountAlreadyDeletedFailure.typeId);
    });
  });
}
