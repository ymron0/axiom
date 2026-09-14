@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_ledger_entries_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('GetLedgerEntriesByAccountIdUseCase', () {
    late MockTransactionRepository repository;
    late GetLedgerEntriesByAccountIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = GetLedgerEntriesByAccountIdUseCase(repository);
    });

    test('returns the repository ledger entries', () async {
      // Given
      final transaction = transactionFixture(id: 'ledger-entry-lookup');
      final accountId = transaction.ledgerEntries.first.accountId;
      final entries = transaction.ledgerEntries;
      when(
        () => repository.getLedgerEntriesByAccountId(accountId),
      ).thenAnswer((_) async => Success<List<LedgerEntry>>(entries));

      // When
      final result = await useCase(accountId);

      // Then
      expect(result.valueOrNull, same(entries));
      verify(() => repository.getLedgerEntriesByAccountId(accountId)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final accountId = AccountId.fromString('ledger-entry-failure');
      const failure = TransactionNotFoundFailure(message: 'read failed');
      when(
        () => repository.getLedgerEntriesByAccountId(accountId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(accountId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
