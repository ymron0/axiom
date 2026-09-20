import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('AccountRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = AccountRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, AccountRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
