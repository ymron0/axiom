import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantAlreadyExistsFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = MerchantAlreadyExistsFailure(message: 'Already exists.');

      expect(failure.message, 'Already exists.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MerchantAlreadyExistsFailure.typeId);
    });
  });
}
