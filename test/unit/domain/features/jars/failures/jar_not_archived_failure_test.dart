import 'package:axiom/src/features/jars/domain/failures/jar_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('JarNotArchivedFailure', () {
    test('preserves its message and returns both typed getters', () {
      const failure = JarNotArchivedFailure(message: 'Not archived.');

      expect(failure.message, 'Not archived.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, JarNotArchivedFailure.typeId);
    });
  });
}
