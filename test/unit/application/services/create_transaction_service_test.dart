@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_command_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateTransactionService', () {
    late MockTransactionRepository repository;
    late MockTagRepository tagRepository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetJarByIdUseCase getJarById;
    late CreateTransactionService service;

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

      service = CreateTransactionService(
        clock: FixedClock(DateTime.utc(2026, 1, 1)),
        createTransaction: CreateTransactionUseCase(repository: repository),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
          getJarById: getJarById,
        ),
        validateTags: ValidateTransactionTagsService(
          getTagsByIds: GetTagsByIdsUseCase(tagRepository),
        ),
      );
    });

    test(
      'creates and returns a transaction when allocations are valid',
      () async {
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

        final result = await service(command);

        final transaction = result.valueOrNull!;

        expect(transaction.kind, command.kind);
        expect(transaction.createdAt, DateTime.utc(2026, 1, 1));

        verify(() => repository.create(transaction)).called(1);
      },
    );

    test('does not persist when an allocated category is missing', () async {
      final command = createTransactionCommandWithCategoryAllocationFixture(
        CategoryId.fromString('missing'),
      );

      when(
        () => getCategoryById(any()),
      ).thenAnswer((_) async => const Success<Category?>(null));

      final result = await service(command);

      expect(result.failureOrNull, isA<AllocationCategoryNotFoundFailure>());

      verifyNever(() => repository.create(any()));
    });

    test(
      'persists when an expense transaction targets an income category',
      () async {
        final category = categoryFixture(
          id: 'income',
          kind: CategoryKind.income,
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

        final result = await service(command);

        expect(result.isSuccess, isTrue);

        verify(() => repository.create(any())).called(1);
      },
    );

    test('propagates category lookup failures without persisting', () async {
      final command = createTransactionCommandWithCategoryAllocationFixture(
        CategoryId.fromString('failed'),
      );

      const failure = CategoryNotFoundFailure(message: 'lookup failed');

      when(() => getCategoryById(any())).thenAnswer((_) async => failure);

      final result = await service(command);

      expect(result.failureOrNull, same(failure));

      verifyNever(() => repository.create(any()));
    });

    test('persists when the transaction has no category allocation', () async {
      final command = createTransactionCommandFixture();

      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      final result = await service(command);

      expect(result.isSuccess, isTrue);

      verifyNever(() => getCategoryById(any()));

      verify(() => repository.create(any())).called(1);
    });

    test('propagates persistence failures', () async {
      final command = createTransactionCommandFixture();

      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');

      when(() => repository.create(any())).thenAnswer((_) async => failure);

      final result = await service(command);

      expect(result.failureOrNull, same(failure));
    });
  });
}
