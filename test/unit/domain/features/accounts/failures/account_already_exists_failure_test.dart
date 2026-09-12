import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountAlreadyExistsFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = AccountAlreadyExistsFailure(message: 'Already exists.');

      expect(failure.message, 'Already exists.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AccountAlreadyExistsFailure.typeId);
    });
  });
}
