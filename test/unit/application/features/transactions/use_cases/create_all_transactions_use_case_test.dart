import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_all_transactions_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_command_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateAllTransactionsUseCase', () {
    late MockTransactionRepository repository;
    late CreateAllTransactionsUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(<Transaction>[]);
    });

    setUp(() {
      repository = MockTransactionRepository();
      useCase = CreateAllTransactionsUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns all created transactions', () async {
      // Given
      final command = CreateAllTransactionsCommand(
        commands: [
          createTransactionCommandFixture(),
          createTransactionCommandFixture(
            effectiveAt: DateTime.utc(2026, 1, 2),
          ),
        ],
      );
      when(
        () => repository.createAll(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(command);

      // Then
      final transactions = result.valueOrNull!;
      expect(
        transactions.map((transaction) => transaction.effectiveAt),
        command.commands.map((command) => command.effectiveAt),
      );
      expect(
        transactions.map((transaction) => transaction.createdAt),
        everyElement(timestamp),
      );
      verify(() => repository.createAll(transactions)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final command = CreateAllTransactionsCommand(
        commands: [createTransactionCommandFixture()],
      );
      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.createAll(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
