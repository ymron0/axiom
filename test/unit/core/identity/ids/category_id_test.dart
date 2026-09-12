import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'category-123';
      expect(CategoryId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = CategoryId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
