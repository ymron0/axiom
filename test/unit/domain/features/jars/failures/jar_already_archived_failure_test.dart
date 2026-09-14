@Tags(['domain'])
library;

import 'package:axiom/src/features/jars/domain/failures/jar_already_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarAlreadyArchivedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarAlreadyArchivedFailure(message: 'Already archived.');

      expect(failure.message, 'Already archived.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarAlreadyArchivedFailure.typeId);
    });
  });
}
