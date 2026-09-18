@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_category_id_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('TransactionSeriesExistByCategoryIdUseCase', () {
    late MockTransactionSeriesRepository repository;
    late TransactionSeriesExistByCategoryIdUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = TransactionSeriesExistByCategoryIdUseCase(
        repository: repository,
      );
    });

    test(
      'returns whether a transaction series references the category',
      () async {
        // Given
        final categoryId = CategoryId.fromString('category-in-use');

        when(
          () => repository.existsByCategoryId(categoryId),
        ).thenAnswer((_) async => const Success(true));

        // When
        final result = await useCase(categoryId);

        // Then
        expect(result.valueOrNull, isTrue);
        verify(() => repository.existsByCategoryId(categoryId)).called(1);
      },
    );

    test('propagates repository failures', () async {
      // Given
      final categoryId = CategoryId.fromString('category-failure');
      const failure = TestTransactionSeriesFailure(message: 'lookup failed');

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
