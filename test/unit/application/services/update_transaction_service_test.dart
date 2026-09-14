@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('UpdateTransactionService', () {
    late MockTransactionRepository repository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetJarByIdUseCase getJarById;
    late UpdateTransactionService service;

    setUpAll(() {
      registerFallbackValue(CategoryId.fromString('mock-category'));
      registerFallbackValue(JarId.fromString('mock-jar'));
      registerFallbackValue(newTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();
      getCategoryById = MockGetCategoryByIdUseCase();
      getJarById = MockGetJarByIdUseCase();
      service = UpdateTransactionService(
        updateTransaction: UpdateTransactionUseCase(repository),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
          getJarById: getJarById,
        ),
      );
    });

    test('updates when allocations are valid', () async {
      // Given
      final category = categoryFixture(
        id: 'groceries',
        kind: CategoryKind.expense,
      );
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: category.id,
      );
      when(
        () => getCategoryById(category.id),
      ).thenAnswer((_) async => Success<Category?>(category));
      when(
        () => repository.update(transaction),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(transaction)).called(1);
    });

    test('does not update when an allocated category is missing', () async {
      // Given
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('missing'),
      );
      when(
        () => getCategoryById(any()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());
      verifyNever(() => repository.update(any()));
    });

    test(
      'does not update when an allocated category has the wrong kind',
      () async {
        // Given
        final category = categoryFixture(
          id: 'income',
          kind: CategoryKind.income,
        );
        final transaction = transactionWithCategoryAllocationFixture(
          categoryId: category.id,
        );
        when(
          () => getCategoryById(any()),
        ).thenAnswer((_) async => Success<Category?>(category));

        // When
        final result = await service(transaction);

        // Then
        expect(
          result.failureOrNull,
          isA<AllocationCategoryKindMismatchFailure>(),
        );
        verifyNever(() => repository.update(any()));
      },
    );

    test('propagates category lookup failures without updating', () async {
      // Given
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('failed'),
      );
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(() => getCategoryById(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => repository.update(any()));
    });

    test('updates when the transaction has no category allocation', () async {
      // Given
      final transaction = transactionFixture(id: 'no-allocation');
      when(
        () => repository.update(transaction),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verifyNever(() => getCategoryById(any()));
      verify(() => repository.update(transaction)).called(1);
    });

    test('propagates persistence failures', () async {
      // Given
      final transaction = transactionFixture(id: 'conflict');
      const failure = TransactionVersionConflictFailure(message: 'conflict');
      when(
        () => repository.update(transaction),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
