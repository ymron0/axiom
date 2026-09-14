@Tags(['domain'])
library;

import 'package:axiom/src/features/accounts/domain/failures/account_already_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('account archival failures', () {
    test('expose messages, typed values, and stable identifiers', () {
      // Given
      const alreadyArchived = AccountAlreadyArchivedFailure(
        message: 'Archived.',
      );
      const notArchived = AccountNotArchivedFailure(message: 'Active.');

      // Then
      expect(alreadyArchived.message, 'Archived.');
      expect(alreadyArchived.failureOrNull, same(alreadyArchived));
      expect(alreadyArchived.type, AccountAlreadyArchivedFailure.typeId);
      expect(notArchived.message, 'Active.');
      expect(notArchived.failureOrNull, same(notArchived));
      expect(notArchived.type, AccountNotArchivedFailure.typeId);
    });
  });
}
