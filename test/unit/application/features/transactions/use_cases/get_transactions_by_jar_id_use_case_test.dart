@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('GetTransactionsByJarIdUseCase', () {
    late MockTransactionRepository repository;
    late GetTransactionsByJarIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = GetTransactionsByJarIdUseCase(repository);
    });

    test('delegates jar lookup to the repository', () async {
      final jarId = JarId.fromString('jar-1');
      when(() => repository.getTransactionsByJarId(jarId)).thenAnswer(
        (_) async => const Success([]),
      );

      final result = await useCase(jarId);

      expect(result.valueOrNull, isEmpty);
      verify(() => repository.getTransactionsByJarId(jarId)).called(1);
    });

    test('propagates repository failures unchanged', () async {
      final jarId = JarId.fromString('jar-1');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(() => repository.getTransactionsByJarId(jarId)).thenAnswer(
        (_) async => failure,
      );

      final result = await useCase(jarId);

      expect(result.failureOrNull, same(failure));
    });
  });
}
