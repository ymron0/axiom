@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/application/services/category_hierarchy_validation.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_kind_mismatch_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('CategoryHierarchyValidation.validateParent', () {
    late MockCategoryRepository repository;

    setUp(() {
      repository = MockCategoryRepository();
    });

    setUpAll(() {
      registerFallbackValue(CategoryId.fromString('fallback'));
    });

    test('accepts a top-level category without loading a parent', () async {
      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: null,
        parentCategoryId: null,
        kind: CategoryKind.expense,
      );

      // Then
      expect(result.isSuccess, isTrue);
      verifyNever(() => repository.getById(any()));
    });

    test('rejects a category as its own parent without loading it', () async {
      // Given
      final category = categoryFixture(id: 'self');

      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: category.id,
        parentCategoryId: category.id,
        kind: category.kind,
      );

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
      verifyNever(() => repository.getById(any()));
    });

    test('rejects an absent parent', () async {
      // Given
      final child = categoryFixture(id: 'child', parentCategoryId: 'missing');
      when(
        () => repository.getById(child.parentCategoryId!),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: child.id,
        parentCategoryId: child.parentCategoryId,
        kind: child.kind,
      );

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
    });

    test('rejects a parent with a different kind', () async {
      // Given
      final child = categoryFixture(id: 'child', parentCategoryId: 'income');
      final parent = categoryFixture(id: 'income', kind: CategoryKind.income);
      when(
        () => repository.getById(parent.id),
      ).thenAnswer((_) async => Success(parent));

      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: child.id,
        parentCategoryId: child.parentCategoryId,
        kind: child.kind,
      );

      // Then
      expect(result.failureOrNull, isA<CategoryKindMismatchFailure>());
    });

    test('rejects a parent that is already a child', () async {
      // Given
      final child = categoryFixture(id: 'child', parentCategoryId: 'parent');
      final parent = categoryFixture(
        id: 'parent',
        parentCategoryId: 'grandparent',
      );
      when(
        () => repository.getById(parent.id),
      ).thenAnswer((_) async => Success(parent));

      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: child.id,
        parentCategoryId: child.parentCategoryId,
        kind: child.kind,
      );

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
    });

    test('rejects an archived parent', () async {
      // Given
      final child = categoryFixture(id: 'child', parentCategoryId: 'parent');
      final archivedAt = DateTime.utc(2026, 1, 2);
      final parent = categoryFixture(
        id: 'parent',
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );
      when(
        () => repository.getById(parent.id),
      ).thenAnswer((_) async => Success(parent));

      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: child.id,
        parentCategoryId: child.parentCategoryId,
        kind: child.kind,
      );

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
    });

    test('preserves parent lookup failures', () async {
      // Given
      final child = categoryFixture(id: 'child', parentCategoryId: 'parent');
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(
        () => repository.getById(child.parentCategoryId!),
      ).thenAnswer((_) async => failure);

      // When
      final result = await CategoryHierarchyValidation.validateParent(
        repository: repository,
        categoryId: child.id,
        parentCategoryId: child.parentCategoryId,
        kind: child.kind,
      );

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
