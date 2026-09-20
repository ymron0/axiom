import 'package:axiom/src/features/merchants/domain/failures/merchant_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = MerchantRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, MerchantRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
