import 'package:axiom/src/features/merchants/domain/value_objects/merchant_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'merchant-123';
      expect(MerchantId.fromString(value).value, value);
    });

    test('self uses the reserved self identifier value', () {
      expect(MerchantId.self.value, 'self');
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = MerchantId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
