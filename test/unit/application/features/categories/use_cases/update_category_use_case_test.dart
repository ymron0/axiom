import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/update_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_kind_mismatch_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('UpdateCategoryUseCase', () {
    late MockCategoryRepository repository;
    late UpdateCategoryUseCase useCase;

    setUp(() {
      repository = MockCategoryRepository();
      useCase = UpdateCategoryUseCase(repository);
    });

    test('rejects a deleted category before any repository operation', () async {
      // Given
      final category = categoryFixture(
        id: 'deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      // When
      final result = await useCase(category);

      // Then
      expect(result.failureOrNull, isA<CategoryAlreadyDeletedFailure>());
      verifyNever(() => repository.getByParentId(category.id));
      verifyNever(() => repository.update(category));
    });

    test('rejects making a category with children into a child', () async {
      // Given
      final category = categoryFixture(id: 'parent', parentCategoryId: 'new-parent');
      final prospectiveParent = categoryFixture(id: 'new-parent');
      final child = categoryFixture(id: 'child', parentCategoryId: 'parent');
      when(
        () => repository.getById(prospectiveParent.id),
      ).thenAnswer((_) async => Success(prospectiveParent));
      when(
        () => repository.getByParentId(category.id),
      ).thenAnswer((_) async => Success<List<Category>>([child]));

      // When
      final result = await useCase(category);

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
      verifyNever(() => repository.update(category));
    });

    test('rejects a parent kind that differs from an existing child', () async {
      // Given
      final category = categoryFixture(id: 'parent', kind: CategoryKind.income);
      final child = categoryFixture(id: 'child', parentCategoryId: 'parent');
      when(
        () => repository.getByParentId(category.id),
      ).thenAnswer((_) async => Success<List<Category>>([child]));

      // When
      final result = await useCase(category);

      // Then
      expect(result.failureOrNull, isA<CategoryKindMismatchFailure>());
      verifyNever(() => repository.update(category));
    });

    test('preserves hierarchy query failures', () async {
      // Given
      final category = categoryFixture(id: 'lookup-failure');
      const failure = CategoryNotFoundFailure(message: 'children unavailable');
      when(
        () => repository.getByParentId(category.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(category);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => repository.update(category));
    });

    test('updates a valid hierarchy-preserving snapshot', () async {
      // Given
      final category = categoryFixture(id: 'groceries');
      when(
        () => repository.getByParentId(category.id),
      ).thenAnswer((_) async => const Success(<Category>[]));
      when(() => repository.update(category)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(category);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(category)).called(1);
    });
  });
}
