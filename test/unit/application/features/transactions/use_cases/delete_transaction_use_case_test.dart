import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('DeleteTransactionUseCase', () {
    late MockTransactionRepository repository;
    late DeleteTransactionUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = DeleteTransactionUseCase(repository);
    });

    test('deletes the transaction and returns a deleted snapshot', () async {
      // Given
      final transaction = transactionFixture(id: 'delete');
      final deletedAt = DateTime.utc(2026, 1, 2);
      when(() => repository.getById(transaction.id)).thenAnswer((_) async => Success<Transaction?>(transaction));
      when(() => repository.delete(transaction.id)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(transaction.id, deletedAt);

      // Then
      expect(result.valueOrNull?.id, transaction.id);
      expect(result.valueOrNull?.deletedAt, deletedAt);
      expect(transaction.deletedAt, isNull);
      verify(() => repository.delete(transaction.id)).called(1);
    });

    test('returns not found without deleting when the lookup is empty', () async {
      // Given
      final id = TransactionId.fromString('missing');
      when(() => repository.getById(id)).thenAnswer((_) async => const Success<Transaction?>(null));

      // When
      final result = await useCase.call(id, DateTime.utc(2026, 1, 2));

      // Then
      expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
      verifyNever(() => repository.delete(id));
    });

    test('propagates lookup failures without deleting', () async {
      // Given
      final id = TransactionId.fromString('lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(id, DateTime.utc(2026, 1, 2));

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => repository.delete(id));
    });

    test('propagates deletion failures', () async {
      // Given
      final transaction = transactionFixture(id: 'delete-failure');
      const failure = TransactionNotFoundFailure(message: 'delete failed');
      when(() => repository.getById(transaction.id)).thenAnswer((_) async => Success<Transaction?>(transaction));
      when(() => repository.delete(transaction.id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(transaction.id, DateTime.utc(2026, 1, 2));

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('rejects a deletion time before creation without deleting', () async {
      // Given
      final transaction = transactionFixture(id: 'invalid-time');
      when(() => repository.getById(transaction.id)).thenAnswer((_) async => Success<Transaction?>(transaction));

      // When / Then
      await expectLater(
        useCase.call(transaction.id, DateTime.utc(2025, 12, 31)),
        throwsArgumentError,
      );
      verifyNever(() => repository.delete(transaction.id));
    });
  });
}
