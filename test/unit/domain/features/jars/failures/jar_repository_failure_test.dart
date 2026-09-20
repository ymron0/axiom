import 'package:axiom/src/features/jars/domain/failures/jar_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = JarRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, JarRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
