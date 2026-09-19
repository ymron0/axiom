@Tags(['core'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('TagId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'tag-123';

      expect(TagId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = TagId.generate();

      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });

    test('rejects a blank persisted identifier', () {
      expect(() => TagId.fromString('   '), throwsArgumentError);
    });
  });
}
