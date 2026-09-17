@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/restore_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('RestoreTransactionService', () {
    late MockTransactionRepository repository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetJarByIdUseCase getJarById;
    late RestoreTransactionService service;

    setUpAll(() {
      registerFallbackValue(CategoryId.fromString('mock-category'));
      registerFallbackValue(JarId.fromString('mock-jar'));
      registerFallbackValue(newTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();
      getCategoryById = MockGetCategoryByIdUseCase();
      getJarById = MockGetJarByIdUseCase();
      service = RestoreTransactionService(
        restoreTransaction: RestoreTransactionUseCase(repository),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
          getJarById: getJarById,
        ),
      );
    });

    test('restores when allocations are valid', () async {
      // Given
      final category = categoryFixture(
        id: 'groceries',
        kind: CategoryKind.expense,
      );
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: category.id,
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => getCategoryById(category.id),
      ).thenAnswer((_) async => Success<Category?>(category));
      when(
        () => repository.restore(transaction),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(transaction)).called(1);
    });

    test('does not restore when an allocated category is missing', () async {
      // Given
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('missing'),
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => getCategoryById(any()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());
      verifyNever(() => repository.restore(any()));
    });

    test(
      'restores when an expense transaction targets an income category',
      () async {
        // Given
        final category = categoryFixture(
          id: 'income',
          kind: CategoryKind.income,
        );

        final transaction = transactionWithCategoryAllocationFixture(
          categoryId: category.id,
          deletedAt: DateTime.utc(2026, 1, 2),
        );

        when(
          () => getCategoryById(category.id),
        ).thenAnswer((_) async => Success<Category?>(category));

        when(
          () => repository.restore(transaction),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(transaction);

        // Then
        expect(result.isSuccess, isTrue);
        verify(() => repository.restore(transaction)).called(1);
      },
    );

    test('propagates category lookup failures without restoring', () async {
      // Given
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('failed'),
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(() => getCategoryById(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => repository.restore(any()));
    });

    test('restores when the transaction has no category allocation', () async {
      // Given
      final transaction = transactionFixture(
        id: 'no-allocation',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.restore(transaction),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verifyNever(() => getCategoryById(any()));
      verify(() => repository.restore(transaction)).called(1);
    });

    test('propagates persistence failures', () async {
      // Given
      final transaction = transactionFixture(
        id: 'existing',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      const failure = TransactionAlreadyExistsFailure(message: 'existing');
      when(
        () => repository.restore(transaction),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
