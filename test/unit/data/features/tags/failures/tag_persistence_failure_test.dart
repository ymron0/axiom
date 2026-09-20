@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/tags/data/failures/tag_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TagPersistenceFailure', () {
    test('exposes its stable type and message', () {
      const failure = TagPersistenceFailure(message: 'storage');

      expect(failure.type, TagPersistenceFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'storage');
    });
  });
}
