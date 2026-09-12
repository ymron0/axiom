import 'package:axiom/src/features/merchants/domain/failures/merchant_already_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantAlreadyDeletedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = MerchantAlreadyDeletedFailure(message: 'Already deleted.');

      expect(failure.message, 'Already deleted.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MerchantAlreadyDeletedFailure.typeId);
    });
  });
}
