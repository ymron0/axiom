@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/features/transactions/data/models/ledger_entry_persistence_model.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('LedgerEntryPersistenceModel', () {
    test('round-trips a transaction ledger entry', () {
      final entry = transactionFixture(id: 'transaction-1').ledgerEntries.single;
      final model = LedgerEntryPersistenceModel.fromEntity(entry);

      expect(
        LedgerEntryPersistenceModel.fromRecord(model.toRecord(), path: 'entries[0]').toEntity(),
        entry,
      );
    });

    test('rejects malformed nested amounts and invalid account identifiers', () {
      final record = LedgerEntryPersistenceModel.fromEntity(
        transactionFixture(id: 'transaction-1').ledgerEntries.single,
      ).toRecord();
      expect(
        () => LedgerEntryPersistenceModel.fromRecord(
          <String, Object?>{...record, 'transactionAmount': 'not-a-map'},
          path: 'entries[0]',
        ),
        throwsA(isA<PersistenceRecordException>()),
      );
      final invalid = LedgerEntryPersistenceModel.fromRecord(
        <String, Object?>{...record, 'accountId': ''},
        path: 'entries[0]',
      );
      expect(invalid.toEntity, throwsArgumentError);
    });
  });
}
