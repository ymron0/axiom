@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  late MockTransactionRepository repository;
  final tagId = TagId.fromString('business');

  setUp(() {
    repository = MockTransactionRepository();
  });

  test('GetTransactionsByTagIdUseCase delegates repository query', () async {
    final transaction = transactionFixture(id: 'transaction', tagIds: [tagId]);

    when(
      () => repository.getTransactionsByTagId(tagId),
    ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

    final result = await GetTransactionsByTagIdUseCase(repository)(tagId);

    expect(result.valueOrNull, [transaction]);
  });

  test('TransactionsExistByTagIdUseCase delegates existence query', () async {
    when(
      () => repository.existsByTagId(tagId),
    ).thenAnswer((_) async => const Success(true));

    final result = await TransactionsExistByTagIdUseCase(repository)(tagId);

    expect(result.valueOrNull, isTrue);
  });
}
