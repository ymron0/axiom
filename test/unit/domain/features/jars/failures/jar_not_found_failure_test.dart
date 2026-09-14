@Tags(['domain'])
library;

import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarNotFoundFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarNotFoundFailure(message: 'Not found.');

      expect(failure.message, 'Not found.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarNotFoundFailure.typeId);
    });
  });
}
