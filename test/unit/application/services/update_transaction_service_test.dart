@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('UpdateTransactionService', () {
    late MockTransactionRepository repository;
    late MockTagRepository tagRepository;
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
      tagRepository = MockTagRepository();
      getCategoryById = MockGetCategoryByIdUseCase();
      getJarById = MockGetJarByIdUseCase();

      service = UpdateTransactionService(
        getTransactionById: GetTransactionByIdUseCase(repository),
        updateTransaction: UpdateTransactionUseCase(repository),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
          getJarById: getJarById,
        ),
        validateTags: ValidateTransactionTagsService(
          getTagsByIds: GetTagsByIdsUseCase(tagRepository),
        ),
      );
    });

    test('updates when allocations are valid', () async {
      final category = categoryFixture(
        id: 'groceries',
        kind: CategoryKind.expense,
      );

      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: category.id,
      );

      when(
        () => repository.getById(transaction.id),
      ).thenAnswer((_) async => Success<Transaction?>(transaction));

      when(
        () => getCategoryById(category.id),
      ).thenAnswer((_) async => Success<Category?>(category));

      when(
        () => repository.update(transaction),
      ).thenAnswer((_) async => const Success(null));

      final result = await service(transaction);

      expect(result.isSuccess, isTrue);

      verify(() => repository.update(transaction)).called(1);
    });

    test('returns not found when the transaction does not exist', () async {
      final transaction = transactionFixture(id: 'missing');

      when(
        () => repository.getById(transaction.id),
      ).thenAnswer((_) async => const Success<Transaction?>(null));

      final result = await service(transaction);

      expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
      expect(
        result.failureOrNull?.message,
        'Transaction ID was not found: missing',
      );

      verifyNever(() => repository.update(any()));
    });

    test('does not update when an allocated category is missing', () async {
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('missing'),
      );

      when(
        () => repository.getById(transaction.id),
      ).thenAnswer((_) async => Success<Transaction?>(transaction));

      when(
        () => getCategoryById(any()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      final result = await service(transaction);

      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());

      verifyNever(() => repository.update(any()));
    });

    test(
      'updates when an expense transaction targets an income category',
      () async {
        final category = categoryFixture(
          id: 'income',
          kind: CategoryKind.income,
        );

        final transaction = transactionWithCategoryAllocationFixture(
          categoryId: category.id,
        );

        when(
          () => repository.getById(transaction.id),
        ).thenAnswer((_) async => Success<Transaction?>(transaction));

        when(
          () => getCategoryById(category.id),
        ).thenAnswer((_) async => Success<Category?>(category));

        when(
          () => repository.update(transaction),
        ).thenAnswer((_) async => const Success(null));

        final result = await service(transaction);

        expect(result.isSuccess, isTrue);

        verify(() => repository.update(transaction)).called(1);
      },
    );

    test('propagates category lookup failures without updating', () async {
      final transaction = transactionWithCategoryAllocationFixture(
        categoryId: CategoryId.fromString('failed'),
      );

      const failure = CategoryNotFoundFailure(message: 'lookup failed');

      when(
        () => repository.getById(transaction.id),
      ).thenAnswer((_) async => Success<Transaction?>(transaction));

      when(() => getCategoryById(any())).thenAnswer((_) async => failure);

      final result = await service(transaction);

      expect(result.failureOrNull, same(failure));

      verifyNever(() => repository.update(any()));
    });

    test('updates when the transaction has no category allocation', () async {
      final transaction = transactionFixture(id: 'no-allocation');

      when(
        () => repository.getById(transaction.id),
      ).thenAnswer((_) async => Success<Transaction?>(transaction));

      when(
        () => repository.update(transaction),
      ).thenAnswer((_) async => const Success(null));

      final result = await service(transaction);

      expect(result.isSuccess, isTrue);

      verifyNever(() => getCategoryById(any()));

      verify(() => repository.update(transaction)).called(1);
    });

    test('propagates persistence failures', () async {
      final transaction = transactionFixture(id: 'conflict');

      const failure = TransactionVersionConflictFailure(message: 'conflict');

      when(
        () => repository.getById(transaction.id),
      ).thenAnswer((_) async => Success<Transaction?>(transaction));

      when(
        () => repository.update(transaction),
      ).thenAnswer((_) async => failure);

      final result = await service(transaction);

      expect(result.failureOrNull, same(failure));
    });
  });
}
