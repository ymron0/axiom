@Tags(['application'])
library;

import 'package:axiom/src/application/services/create_transaction_offset_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_offset_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/transactions/transaction_offset_fixtures.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateTransactionOffsetService', () {
    late MockTransactionRepository repository;
    late MockTagRepository tagRepository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetJarByIdUseCase getJarById;
    late CreateTransactionOffsetService service;

    setUpAll(() {
      registerFallbackValue(CategoryId.fromString('fallback-category'));

      registerFallbackValue(JarId.fromString('fallback-jar'));

      registerFallbackValue(offsetTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();
      tagRepository = MockTagRepository();
      getCategoryById = MockGetCategoryByIdUseCase();
      getJarById = MockGetJarByIdUseCase();

      service = CreateTransactionOffsetService(
        clock: FixedClock(DateTime.utc(2026, 1, 2)),
        getTransactionById: GetTransactionByIdUseCase(repository),
        createTransactionOffset: CreateTransactionOffsetUseCase(
          repository: repository,
        ),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
          getJarById: getJarById,
        ),
        validateTags: ValidateTransactionTagsService(
          getTagsByIds: GetTagsByIdsUseCase(tagRepository),
        ),
        offsetPolicy: const TransactionOffsetPolicy(),
      );
    });

    test(
      'creates reimbursement as actual income linked to original expense',
      () async {
        final original = offsetOriginalTransactionFixture();

        final command = transactionOffsetCommandFixture(
          originalTransactionId: original.id,
        );

        when(
          () => repository.getById(original.id),
        ).thenAnswer((_) async => Success<Transaction?>(original));

        when(
          () => repository.createOffset(any()),
        ).thenAnswer((_) async => const Success(null));

        final result = await service(command);

        final transaction = result.valueOrNull!;

        expect(transaction.kind, TransactionKind.income);
        expect(transaction.state, TransactionState.actual);
        expect(transaction.offset!.originalTransactionId, original.id);
        expect(transaction.offset!.kind, command.offsetKind);
        expect(transaction.merchantId, command.merchantId);

        verify(() => repository.createOffset(transaction)).called(1);
      },
    );

    test(
      'creates offset as actual expense linked to original income',
      () async {
        final original = offsetOriginalTransactionFixture(
          kind: TransactionKind.income,
        );

        final command = transactionOffsetCommandFixture(
          originalTransactionId: original.id,
          transactionKind: TransactionKind.expense,
        );

        when(
          () => repository.getById(original.id),
        ).thenAnswer((_) async => Success<Transaction?>(original));

        when(
          () => repository.createOffset(any()),
        ).thenAnswer((_) async => const Success(null));

        final result = await service(command);

        final transaction = result.valueOrNull!;

        expect(transaction.kind, TransactionKind.expense);
        expect(transaction.state, TransactionState.actual);
        expect(transaction.offset!.originalTransactionId, original.id);

        verify(() => repository.createOffset(transaction)).called(1);
      },
    );

    test(
      'returns not-found when original transaction does not exist',
      () async {
        final command = transactionOffsetCommandFixture();

        when(
          () => repository.getById(command.originalTransactionId),
        ).thenAnswer((_) async => const Success<Transaction?>(null));

        final result = await service(command);

        expect(result.failureOrNull, isA<TransactionNotFoundFailure>());

        verifyNever(() => repository.createOffset(any()));
      },
    );

    test('does not persist an offset larger than original', () async {
      final original = offsetOriginalTransactionFixture(
        amount: Decimal.fromInt(100),
      );

      final command = transactionOffsetCommandFixture(
        originalTransactionId: original.id,
        amount: Decimal.fromInt(101),
      );

      when(
        () => repository.getById(original.id),
      ).thenAnswer((_) async => Success<Transaction?>(original));

      final result = await service(command);

      expect(result.isFailure, isTrue);

      verifyNever(() => repository.createOffset(any()));
    });

    test('returns the persistence failure', () async {
      final original = offsetOriginalTransactionFixture();

      final command = transactionOffsetCommandFixture(
        originalTransactionId: original.id,
      );

      const failure = TransactionOffsetValidationFailure(
        message: 'persistence rejected offset',
      );

      when(
        () => repository.getById(original.id),
      ).thenAnswer((_) async => Success<Transaction?>(original));

      when(
        () => repository.createOffset(any()),
      ).thenAnswer((_) async => failure);

      final result = await service(command);

      expect(result.failureOrNull, same(failure));

      verify(() => repository.createOffset(any())).called(1);
    });
  });
}
