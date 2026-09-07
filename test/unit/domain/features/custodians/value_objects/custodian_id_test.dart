import 'package:axiom/src/features/custodians/domain/value_objects/custodian_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'custodian-123';
      expect(CustodianId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = CustodianId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
