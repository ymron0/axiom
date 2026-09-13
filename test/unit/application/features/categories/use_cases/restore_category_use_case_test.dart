import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/restore_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/categories/category_fixtures.dart';
import '../../../../../mocks/category_repository_mock.dart';

void main() {
  group('RestoreCategoryUseCase', () {
    late MockCategoryRepository repository;
    late RestoreCategoryUseCase useCase;

    setUp(() {
      repository = MockCategoryRepository();
      useCase = RestoreCategoryUseCase(repository);
    });

    test('rejects an active snapshot before persistence', () async {
      // Given
      final category = categoryFixture(id: 'active');

      // When
      final result = await useCase(category);

      // Then
      expect(result.failureOrNull, isA<CategoryAlreadyActiveFailure>());
      verifyNever(() => repository.restore(category));
    });

    test('rejects restoration when the parent is absent', () async {
      // Given
      final category = categoryFixture(
        id: 'child',
        parentCategoryId: 'missing',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.getById(category.parentCategoryId!),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(category);

      // Then
      expect(result.failureOrNull, isA<CategoryInvalidParentFailure>());
      verifyNever(() => repository.restore(category));
    });

    test('restores a deleted category when its hierarchy remains valid', () async {
      // Given
      final category = categoryFixture(
        id: 'groceries',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(() => repository.restore(category)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(category);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(category)).called(1);
    });
  });
}
