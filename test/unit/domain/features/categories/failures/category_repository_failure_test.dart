import 'package:axiom/src/features/categories/domain/failures/category_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = CategoryRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, CategoryRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
