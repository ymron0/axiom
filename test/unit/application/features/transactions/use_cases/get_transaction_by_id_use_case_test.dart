import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('GetTransactionByIdUseCase', () {
    late MockTransactionRepository repository;
    late GetTransactionByIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = GetTransactionByIdUseCase(repository);
    });

    test('returns the matching repository transaction', () async {
      // Given
      final transaction = transactionFixture(id: 'by-id');
      when(() => repository.getById(transaction.id)).thenAnswer((_) async => Success<Transaction?>(transaction));

      // When
      final result = await useCase.call(transaction.id);

      // Then
      expect(result.valueOrNull, same(transaction));
      verify(() => repository.getById(transaction.id)).called(1);
    });

    test('preserves a missing transaction result', () async {
      // Given
      final id = TransactionId.fromString('missing');
      when(() => repository.getById(id)).thenAnswer((_) async => const Success<Transaction?>(null));

      // When
      final result = await useCase.call(id);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('propagates repository failures', () async {
      // Given
      final id = TransactionId.fromString('failed');
      const failure = TransactionNotFoundFailure(message: 'read failed');
      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
