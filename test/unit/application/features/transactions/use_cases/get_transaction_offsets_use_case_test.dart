@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_offsets_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_offset_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('GetTransactionOffsetsUseCase', () {
    late MockTransactionRepository repository;
    late GetTransactionOffsetsUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();

      useCase = GetTransactionOffsetsUseCase(repository: repository);
    });

    test('delegates offset query to repository', () async {
      final id = TransactionId.fromString('original');
      final offsets = [offsetTransactionFixture()];

      when(
        () => repository.getOffsetsForTransaction(id),
      ).thenAnswer((_) async => Success<List<Transaction>>(offsets));

      final result = await useCase(id);

      expect(result.valueOrNull, same(offsets));

      verify(() => repository.getOffsetsForTransaction(id)).called(1);
    });

    test('propagates repository failure', () async {
      final id = TransactionId.fromString('original');

      const failure = TransactionOffsetValidationFailure(message: 'failed');

      when(
        () => repository.getOffsetsForTransaction(id),
      ).thenAnswer((_) async => failure);

      final result = await useCase(id);

      expect(result.failureOrNull, same(failure));
    });
  });
}
