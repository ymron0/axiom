import 'package:axiom/src/features/merchants/domain/failures/invalid_merchant_name_failure.dart';
import 'package:test/test.dart';

void main() {
  group('InvalidMerchantNameFailure', () {
    test('exposes its message, failure value, and stable type', () {
      const failure = InvalidMerchantNameFailure(
        message: 'Merchant name cannot be blank.',
      );

      expect(failure.message, 'Merchant name cannot be blank.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, InvalidMerchantNameFailure.typeId);
    });
  });
}
