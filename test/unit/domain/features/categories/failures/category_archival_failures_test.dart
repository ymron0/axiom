@Tags(['domain'])
library;

import 'package:axiom/src/features/categories/domain/failures/category_already_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('category archival failures', () {
    test('expose stable identifiers', () {
      // Given
      const alreadyArchived = CategoryAlreadyArchivedFailure(
        message: 'Archived.',
      );
      const notArchived = CategoryNotArchivedFailure(message: 'Active.');

      // Then
      expect(alreadyArchived.type, CategoryAlreadyArchivedFailure.typeId);
      expect(alreadyArchived.failureOrNull, same(alreadyArchived));
      expect(notArchived.type, CategoryNotArchivedFailure.typeId);
      expect(notArchived.failureOrNull, same(notArchived));
    });
  });
}
