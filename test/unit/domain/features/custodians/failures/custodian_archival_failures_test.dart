@Tags(['domain'])
library;

import 'package:axiom/src/features/custodians/domain/failures/custodian_already_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('custodian archival failures', () {
    test('expose messages, typed values, and stable identifiers', () {
      // Given
      const alreadyArchived = CustodianAlreadyArchivedFailure(
        message: 'Archived.',
      );
      const notArchived = CustodianNotArchivedFailure(message: 'Active.');

      // Then
      expect(alreadyArchived.message, 'Archived.');
      expect(alreadyArchived.failureOrNull, same(alreadyArchived));
      expect(alreadyArchived.type, CustodianAlreadyArchivedFailure.typeId);
      expect(notArchived.message, 'Active.');
      expect(notArchived.failureOrNull, same(notArchived));
      expect(notArchived.type, CustodianNotArchivedFailure.typeId);
    });
  });
}
