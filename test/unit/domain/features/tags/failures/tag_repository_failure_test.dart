import 'package:axiom/src/features/tags/domain/failures/tag_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TagRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = TagRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, TagRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
