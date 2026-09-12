import 'package:axiom/src/features/accounts/domain/failures/account_in_use_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountInUseFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = AccountInUseFailure(message: 'Account is in use.');

      expect(failure.message, 'Account is in use.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AccountInUseFailure.typeId);
    });
  });
}
