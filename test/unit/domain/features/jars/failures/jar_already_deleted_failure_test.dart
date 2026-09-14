@Tags(['domain'])
library;

import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarAlreadyDeletedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarAlreadyDeletedFailure(message: 'Already deleted.');

      expect(failure.message, 'Already deleted.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarAlreadyDeletedFailure.typeId);
    });
  });
}
