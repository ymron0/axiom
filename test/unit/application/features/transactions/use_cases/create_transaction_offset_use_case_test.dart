@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_offset_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_offset_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateTransactionOffsetUseCase', () {
    late MockTransactionRepository repository;
    late CreateTransactionOffsetUseCase useCase;

    setUpAll(() {
      registerFallbackValue(offsetTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();

      useCase = CreateTransactionOffsetUseCase(repository: repository);
    });

    test('delegates atomic offset creation to repository', () async {
      final transaction = offsetTransactionFixture();

      when(
        () => repository.createOffset(transaction),
      ).thenAnswer((_) async => const Success(null));

      final result = await useCase(transaction);

      expect(result.isSuccess, isTrue);

      verify(() => repository.createOffset(transaction)).called(1);
    });

    test('propagates repository failure', () async {
      final transaction = offsetTransactionFixture();

      const failure = TransactionOffsetValidationFailure(message: 'invalid');

      when(
        () => repository.createOffset(transaction),
      ).thenAnswer((_) async => failure);

      final result = await useCase(transaction);

      expect(result.failureOrNull, same(failure));
    });
  });
}
