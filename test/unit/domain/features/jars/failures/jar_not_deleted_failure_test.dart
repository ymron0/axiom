@Tags(['domain'])
library;

import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarNotDeletedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarNotDeletedFailure(message: 'Not deleted.');

      expect(failure.message, 'Not deleted.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarNotDeletedFailure.typeId);
    });
  });
}
