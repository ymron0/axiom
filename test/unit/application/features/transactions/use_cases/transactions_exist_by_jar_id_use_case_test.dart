import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('TransactionsExistByJarIdUseCase', () {
    late MockTransactionRepository repository;
    late TransactionsExistByJarIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = TransactionsExistByJarIdUseCase(repository);
    });

    test('returns whether persisted transactions reference the jar', () async {
      // Given
      final jarId = JarId.fromString('jar-in-use');
      when(
        () => repository.existsByJarId(jarId),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await useCase(jarId);

      // Then
      expect(result.valueOrNull, isTrue);
      verify(() => repository.existsByJarId(jarId)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final jarId = JarId.fromString('lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(() => repository.existsByJarId(jarId)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(jarId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
