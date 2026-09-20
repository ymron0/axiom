@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  late MockTransactionRepository repository;
  late GetTransactionsByAccountIdUseCase useCase;

  final accountId = AccountId.fromString('account-eur');

  setUp(() {
    repository = MockTransactionRepository();
    useCase = GetTransactionsByAccountIdUseCase(repository);
  });

  test('delegates account transaction lookup to the repository', () async {
    final transactions = [
      transactionFixture(id: 'transaction-1'),
      transactionFixture(id: 'transaction-2'),
    ];

    when(
      () => repository.getTransactionsByAccountId(accountId),
    ).thenAnswer((_) async => Success<List<Transaction>>(transactions));

    final result = await useCase(accountId);

    expect(result.valueOrNull, same(transactions));

    verify(() => repository.getTransactionsByAccountId(accountId)).called(1);
  });

  test('propagates repository failure', () async {
    const failure = TransactionRepositoryFailure(message: 'query failed');

    when(
      () => repository.getTransactionsByAccountId(accountId),
    ).thenAnswer((_) async => failure);

    final result = await useCase(accountId);

    expect(result.failureOrNull, same(failure));
  });
}
