import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/di/create_all_transactions_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/delete_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_all_transactions_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/restore_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('transaction use-case providers', () {
    test('resolves every use case from the default repository', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(transactionRepositoryProvider);
      final useCases = [
        container.read(createTransactionUseCaseProvider),
        container.read(createAllTransactionsUseCaseProvider),
        container.read(getAllTransactionsUseCaseProvider),
        container.read(getTransactionByIdUseCaseProvider),
        container.read(queryTransactionsUseCaseProvider),
        container.read(updateTransactionUseCaseProvider),
        container.read(deleteTransactionUseCaseProvider),
        container.read(restoreTransactionUseCaseProvider),
      ];

      // Then
      expect(repository, isA<InMemoryTransactionRepositoryImpl>());
      expect(useCases, hasLength(8));
      expect(useCases[0], isA<CreateTransactionUseCase>());
      expect(useCases[1], isA<CreateAllTransactionsUseCase>());
      expect(useCases[2], isA<GetAllTransactionsUseCase>());
      expect(useCases[3], isA<GetTransactionByIdUseCase>());
      expect(useCases[4], isA<QueryTransactionsUseCase>());
      expect(useCases[5], isA<UpdateTransactionUseCase>());
      expect(useCases[6], isA<DeleteTransactionUseCase>());
      expect(useCases[7], isA<RestoreTransactionUseCase>());
    });

    test('injects an overridden repository into every use case', () async {
      // Given
      final repository = MockTransactionRepository();
      final transaction = transactionFixture(id: 'provider-transaction');
      final deleted = transactionFixture(
        id: 'provider-deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      final transactions = [transaction];
      final query = TransactionQuery();
      when(() => repository.create(transaction)).thenAnswer(
        (_) async => const Success(null),
      );
      when(() => repository.createAll(transactions)).thenAnswer(
        (_) async => const Success(null),
      );
      when(() => repository.getAll()).thenAnswer(
        (_) async => Success<List<Transaction>>(transactions),
      );
      when(() => repository.getById(transaction.id)).thenAnswer(
        (_) async => Success<Transaction?>(transaction),
      );
      when(() => repository.query(query)).thenAnswer(
        (_) async => Success<List<Transaction>>(transactions),
      );
      when(() => repository.update(transaction)).thenAnswer(
        (_) async => const Success(null),
      );
      when(() => repository.delete(transaction.id)).thenAnswer(
        (_) async => const Success(null),
      );
      when(() => repository.restore(deleted)).thenAnswer(
        (_) async => const Success(null),
      );
      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // When
      await container.read(createTransactionUseCaseProvider)(transaction);
      await container.read(createAllTransactionsUseCaseProvider)(transactions);
      await container.read(getAllTransactionsUseCaseProvider)();
      await container.read(getTransactionByIdUseCaseProvider)(transaction.id);
      await container.read(queryTransactionsUseCaseProvider)(query);
      await container.read(updateTransactionUseCaseProvider)(transaction);
      await container.read(deleteTransactionUseCaseProvider)(
        transaction.id,
        DateTime.utc(2026, 1, 2),
      );
      await container.read(restoreTransactionUseCaseProvider)(deleted);

      // Then
      verify(() => repository.create(transaction)).called(1);
      verify(() => repository.createAll(transactions)).called(1);
      verify(() => repository.getAll()).called(1);
      verify(() => repository.getById(transaction.id)).called(2);
      verify(() => repository.query(query)).called(1);
      verify(() => repository.update(transaction)).called(1);
      verify(() => repository.delete(transaction.id)).called(1);
      verify(() => repository.restore(deleted)).called(1);
    });
  });
}
