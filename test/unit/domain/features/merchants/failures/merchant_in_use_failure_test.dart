import 'package:axiom/src/features/merchants/domain/failures/merchant_in_use_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantInUseFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = MerchantInUseFailure(message: 'Merchant is in use.');

      expect(failure.message, 'Merchant is in use.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MerchantInUseFailure.typeId);
    });
  });
}
