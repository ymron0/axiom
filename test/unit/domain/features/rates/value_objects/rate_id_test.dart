import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('RateId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'rate-123';
      expect(RateId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = RateId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
