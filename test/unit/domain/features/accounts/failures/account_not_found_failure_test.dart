import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountNotFoundFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = AccountNotFoundFailure(message: 'Not found.');

      expect(failure.message, 'Not found.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, AccountNotFoundFailure.typeId);
    });
  });
}
