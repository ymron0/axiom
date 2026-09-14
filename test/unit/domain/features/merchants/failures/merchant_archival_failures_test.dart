@Tags(['domain'])
library;

import 'package:axiom/src/features/merchants/domain/failures/merchant_already_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('merchant archival failures', () {
    test('expose stable identifiers', () {
      // Given
      const alreadyArchived = MerchantAlreadyArchivedFailure(message: 'Archived.');
      const notArchived = MerchantNotArchivedFailure(message: 'Active.');

      // Then
      expect(alreadyArchived.type, MerchantAlreadyArchivedFailure.typeId);
      expect(alreadyArchived.failureOrNull, same(alreadyArchived));
      expect(notArchived.type, MerchantNotArchivedFailure.typeId);
      expect(notArchived.failureOrNull, same(notArchived));
    });
  });
}
