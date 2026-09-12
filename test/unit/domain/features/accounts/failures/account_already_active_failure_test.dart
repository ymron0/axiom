import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountAlreadyActiveFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = AccountAlreadyActiveFailure(message: 'Already active.');

      expect(failure.message, 'Already active.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AccountAlreadyActiveFailure.typeId);
    });
  });
}
