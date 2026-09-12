import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantNotFoundFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = MerchantNotFoundFailure(message: 'Not found.');

      expect(failure.message, 'Not found.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MerchantNotFoundFailure.typeId);
    });
  });
}
