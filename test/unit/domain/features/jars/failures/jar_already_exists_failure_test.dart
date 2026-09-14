import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarAlreadyExistsFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarAlreadyExistsFailure(message: 'Already exists.');

      expect(failure.message, 'Already exists.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarAlreadyExistsFailure.typeId);
    });
  });
}
