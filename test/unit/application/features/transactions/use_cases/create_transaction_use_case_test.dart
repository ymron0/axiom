import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_command_fixtures.dart';
import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateTransactionUseCase', () {
    late MockTransactionRepository repository;
    late CreateTransactionUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(newTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();
      useCase = CreateTransactionUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns the created transaction', () async {
      // Given
      final command = createTransactionCommandFixture();
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(command);

      // Then
      final transaction = result.valueOrNull!;
      expect(transaction, isA<Transaction>());
      expect(transaction.kind, command.kind);
      expect(transaction.merchantId, command.merchantId);
      expect(transaction.createdAt, timestamp);
      expect(transaction.modifiedAt, timestamp);
      expect(transaction.entityVersion, 1);
      verify(() => repository.create(transaction)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final command = createTransactionCommandFixture();
      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
