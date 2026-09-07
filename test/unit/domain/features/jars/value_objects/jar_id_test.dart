import 'package:axiom/src/features/jars/domain/value_objects/jar_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('JarId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'jar-123';
      expect(JarId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = JarId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
