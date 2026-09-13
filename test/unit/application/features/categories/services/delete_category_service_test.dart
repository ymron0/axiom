import 'package:axiom/src/application/services/delete_category_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_in_use_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('DeleteCategoryService', () {
    late MockCategoryRepository categoryRepository;
    late MockTransactionRepository transactionRepository;
    late DeleteCategoryService service;

    setUp(() {
      categoryRepository = MockCategoryRepository();
      transactionRepository = MockTransactionRepository();
      service = DeleteCategoryService(
        getCategoryById: GetCategoryByIdUseCase(categoryRepository),
        getCategories: GetCategoriesUseCase(categoryRepository),
        transactionsExist: TransactionsExistByCategoryIdUseCase(
          transactionRepository,
        ),
        deleteCategory: DeleteCategoryUseCase(categoryRepository),
      );
    });

    test('preserves category lookup failures without further checks', () async {
      // Given
      final category = categoryFixture(id: 'lookup-failure');
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(
        () => categoryRepository.getById(category.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(category.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => categoryRepository.getAll());
      verifyNever(() => transactionRepository.existsByCategoryId(category.id));
      verifyNever(() => categoryRepository.delete(category.id));
    });

    test('returns not found when the category is absent', () async {
      // Given
      final category = categoryFixture(id: 'missing');
      when(
        () => categoryRepository.getById(category.id),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(category.id);

      // Then
      expect(result.failureOrNull, isA<CategoryNotFoundFailure>());
      verifyNever(() => categoryRepository.getAll());
      verifyNever(() => categoryRepository.delete(category.id));
    });

    test(
      'rejects a deleted category before hierarchy or usage checks',
      () async {
        // Given
        final category = categoryFixture(
          id: 'deleted',
          deletedAt: DateTime.utc(2026, 1, 2),
        );
        when(
          () => categoryRepository.getById(category.id),
        ).thenAnswer((_) async => Success(category));

        // When
        final result = await service(category.id);

        // Then
        expect(result.failureOrNull, isA<CategoryAlreadyDeletedFailure>());
        verifyNever(() => categoryRepository.getAll());
        verifyNever(
          () => transactionRepository.existsByCategoryId(category.id),
        );
        verifyNever(() => categoryRepository.delete(category.id));
      },
    );

    test('rejects a category that still has children', () async {
      // Given
      final category = categoryFixture(id: 'parent');
      final child = categoryFixture(id: 'child', parentCategoryId: 'parent');
      when(
        () => categoryRepository.getById(category.id),
      ).thenAnswer((_) async => Success(category));
      when(
        () => categoryRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Category>>([category, child]));

      // When
      final result = await service(category.id);

      // Then
      expect(result.failureOrNull, isA<CategoryInUseFailure>());
      verifyNever(() => transactionRepository.existsByCategoryId(category.id));
      verifyNever(() => categoryRepository.delete(category.id));
    });

    test('rejects a category referenced by a transaction', () async {
      // Given
      final category = categoryFixture(id: 'referenced');
      when(
        () => categoryRepository.getById(category.id),
      ).thenAnswer((_) async => Success(category));
      when(
        () => categoryRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));
      when(
        () => transactionRepository.existsByCategoryId(category.id),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await service(category.id);

      // Then
      expect(result.failureOrNull, isA<CategoryInUseFailure>());
      verifyNever(() => categoryRepository.delete(category.id));
    });

    test('preserves transaction usage lookup failures', () async {
      // Given
      final category = categoryFixture(id: 'usage-failure');
      const failure = TransactionNotFoundFailure(message: 'usage unavailable');
      when(
        () => categoryRepository.getById(category.id),
      ).thenAnswer((_) async => Success(category));
      when(
        () => categoryRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));
      when(
        () => transactionRepository.existsByCategoryId(category.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(category.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => categoryRepository.delete(category.id));
    });

    test('deletes a category only after every guard passes', () async {
      // Given
      final category = categoryFixture(id: 'unused');
      final deleted = categoryFixture(
        id: 'unused',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => categoryRepository.getById(category.id),
      ).thenAnswer((_) async => Success(category));
      when(
        () => categoryRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Category>>([category]));
      when(
        () => transactionRepository.existsByCategoryId(category.id),
      ).thenAnswer((_) async => const Success(false));
      when(
        () => categoryRepository.delete(category.id),
      ).thenAnswer((_) async => Success(deleted));

      // When
      final result = await service(category.id);

      // Then
      expect(result.valueOrNull, same(deleted));
      verify(() => categoryRepository.delete(category.id)).called(1);
    });
  });
}
