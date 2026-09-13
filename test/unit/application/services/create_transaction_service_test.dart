import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_command_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateTransactionService', () {
    late MockTransactionRepository repository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late CreateTransactionService service;

    setUpAll(() {
      registerFallbackValue(CategoryId.fromString('mock-category'));
      registerFallbackValue(newTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();
      getCategoryById = MockGetCategoryByIdUseCase();
      service = CreateTransactionService(
        clock: FixedClock(DateTime.utc(2026, 1, 1)),
        createTransaction: CreateTransactionUseCase(repository: repository),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
        ),
      );
    });

    test(
      'creates and returns a transaction when allocations are valid',
      () async {
        // Given
        final category = categoryFixture(
          id: 'groceries',
          kind: CategoryKind.expense,
        );
        final command = createTransactionCommandWithCategoryAllocationFixture(
          category.id,
        );
        when(
          () => getCategoryById(category.id),
        ).thenAnswer((_) async => Success<Category?>(category));
        when(
          () => repository.create(any()),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(command);

        // Then
        final transaction = result.valueOrNull!;
        expect(transaction.kind, command.kind);
        expect(transaction.createdAt, DateTime.utc(2026, 1, 1));
        verify(() => repository.create(transaction)).called(1);
      },
    );

    test('does not persist when an allocated category is missing', () async {
      // Given
      final command = createTransactionCommandWithCategoryAllocationFixture(
        CategoryId.fromString('missing'),
      );
      when(
        () => getCategoryById(any()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      // When
      final result = await service(command);

      // Then
      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());
      verifyNever(() => repository.create(any()));
    });

    test(
      'does not persist when an allocated category has the wrong kind',
      () async {
        // Given
        final category = categoryFixture(
          id: 'income',
          kind: CategoryKind.income,
        );
        final command = createTransactionCommandWithCategoryAllocationFixture(
          category.id,
        );
        when(
          () => getCategoryById(any()),
        ).thenAnswer((_) async => Success<Category?>(category));

        // When
        final result = await service(command);

        // Then
        expect(
          result.failureOrNull,
          isA<AllocationCategoryKindMismatchFailure>(),
        );
        verifyNever(() => repository.create(any()));
      },
    );

    test('propagates category lookup failures without persisting', () async {
      // Given
      final command = createTransactionCommandWithCategoryAllocationFixture(
        CategoryId.fromString('failed'),
      );
      const failure = CategoryNotFoundFailure(message: 'lookup failed');
      when(() => getCategoryById(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(command);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => repository.create(any()));
    });

    test('persists when the transaction has no category allocation', () async {
      // Given
      final command = createTransactionCommandFixture();
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(command);

      // Then
      expect(result.isSuccess, isTrue);
      verifyNever(() => getCategoryById(any()));
      verify(() => repository.create(any())).called(1);
    });

    test('propagates persistence failures', () async {
      // Given
      final command = createTransactionCommandFixture();
      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
