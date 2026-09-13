import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('TransactionsExistByCategoryIdUseCase', () {
    late MockTransactionRepository repository;
    late TransactionsExistByCategoryIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = TransactionsExistByCategoryIdUseCase(repository);
    });

    test('returns whether persisted transactions reference the category', () async {
      // Given
      final categoryId = CategoryId.fromString('groceries');
      when(
        () => repository.existsByCategoryId(categoryId),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await useCase(categoryId);

      // Then
      expect(result.valueOrNull, isTrue);
      verify(() => repository.existsByCategoryId(categoryId)).called(1);
    });

    test('preserves repository failures', () async {
      // Given
      final categoryId = CategoryId.fromString('lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(
        () => repository.existsByCategoryId(categoryId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(categoryId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
