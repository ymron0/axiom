import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/application/services/delete_jar_service.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_in_use_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../mocks/delete_jar_use_case_mock.dart';
import '../../../mocks/transactions_exist_by_jar_id_use_case_mock.dart';

void main() {
  group('DeleteJarService', () {
    late MockTransactionsExistByJarIdUseCase transactionsExistByJarId;
    late MockDeleteJarUseCase deleteJar;
    late DeleteJarService service;

    setUp(() {
      transactionsExistByJarId = MockTransactionsExistByJarIdUseCase();
      deleteJar = MockDeleteJarUseCase();
      service = DeleteJarService(
        transactionsExistByJarId: transactionsExistByJarId,
        deleteJar: deleteJar,
      );
    });

    test('deletes a jar when no transaction references it', () async {
      // Given
      final jarId = JarId.fromString('unused');
      final deletedJar = jarFixture(
        id: jarId.value,
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => transactionsExistByJarId(jarId),
      ).thenAnswer((_) async => const Success(false));
      when(() => deleteJar(jarId)).thenAnswer((_) async => Success<Jar>(deletedJar));

      // When
      final result = await service(jarId);

      // Then
      expect(result.valueOrNull, same(deletedJar));
      verify(() => transactionsExistByJarId(jarId)).called(1);
      verify(() => deleteJar(jarId)).called(1);
    });

    test('rejects deletion when a transaction references the jar', () async {
      // Given
      final jarId = JarId.fromString('in-use');
      when(
        () => transactionsExistByJarId(jarId),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, isA<JarInUseFailure>());
      verifyNever(() => deleteJar(jarId));
    });

    test('propagates transaction-query failures without deleting', () async {
      // Given
      final jarId = JarId.fromString('lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(() => transactionsExistByJarId(jarId)).thenAnswer((_) async => failure);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => deleteJar(jarId));
    });

    test('propagates jar-deletion failures', () async {
      // Given
      final jarId = JarId.fromString('missing');
      const failure = JarNotFoundFailure(message: 'missing');
      when(
        () => transactionsExistByJarId(jarId),
      ).thenAnswer((_) async => const Success(false));
      when(() => deleteJar(jarId)).thenAnswer((_) async => failure);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
