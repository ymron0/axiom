import 'package:axiom/src/features/merchants/domain/failures/merchant_already_active_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantAlreadyActiveFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = MerchantAlreadyActiveFailure(message: 'Already active.');

      expect(failure.message, 'Already active.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MerchantAlreadyActiveFailure.typeId);
    });
  });
}
