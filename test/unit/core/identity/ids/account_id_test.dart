import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('AccountId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'account-123';

      final accountId = AccountId.fromString(value);

      expect(accountId.value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final accountId = AccountId.generate();
      final allowedCharacters = urlAlphabet.split('');

      expect(accountId.value, isNotEmpty);
      expect(
        accountId.value.split(''),
        everyElement(isIn(allowedCharacters)),
      );
    });
  });
}
