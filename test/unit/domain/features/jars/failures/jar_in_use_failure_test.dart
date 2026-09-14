import 'package:axiom/src/features/jars/domain/failures/jar_in_use_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarInUseFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarInUseFailure(message: 'Jar is in use.');

      expect(failure.message, 'Jar is in use.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarInUseFailure.typeId);
    });
  });
}
