@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';
import '../../../mocks/validate_transaction_budgets_service_mock.dart';

void main() {
  group('UpdateTransactionService', () {
    late MockTransactionRepository repository;
    late MockAssetRepository assetRepository;
    late MockSettingsRepository settingsRepository;
    late MockTagRepository tagRepository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetJarByIdUseCase getJarById;
    late MockValidateTransactionBudgetsService validateBudgets;
    late UpdateTransactionService service;

    setUpAll(() {
      registerFallbackValue(CategoryId.fromString('mock-category'));
      registerFallbackValue(JarId.fromString('mock-jar'));
      registerFallbackValue(AssetId.fromString('mock-asset'));
      registerFallbackValue(newTransactionFixture());
    });

    setUp(() {
      repository = MockTransactionRepository();
      assetRepository = MockAssetRepository();
      settingsRepository = MockSettingsRepository();
      tagRepository = MockTagRepository();
      getCategoryById = MockGetCategoryByIdUseCase();
      getJarById = MockGetJarByIdUseCase();
      validateBudgets = MockValidateTransactionBudgetsService();

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: AssetId.fromString('asset-eur')),
        ),
      );

      when(() => assetRepository.getById(any())).thenAnswer((invocation) async {
        final assetId = invocation.positionalArguments.single as AssetId;

        return Success(currencyFixture(id: assetId.value));
      });

      when(() => assetRepository.getByIds(any())).thenAnswer((
        invocation,
      ) async {
        final ids = invocation.positionalArguments.single as List<AssetId>;

        return Success(
          BatchLookup(
            found: [for (final id in ids) currencyFixture(id: id.value)],
            missing: const [],
          ),
        );
      });

      when(
        () => validateBudgets(any(), previous: any(named: 'previous')),
      ).thenAnswer((_) async => const Success(null));

      service = UpdateTransactionService(
        getTransactionById: GetTransactionByIdUseCase(repository),
        updateTransaction: UpdateTransactionUseCase(repository),
        validateAssets: ValidateTransactionAssetSemanticsService(
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
          getValuationCurrency: GetValuationCurrencyService(
            getSettings: GetSettingsUseCase(settingsRepository),
            getAssetById: GetAssetByIdUseCase(assetRepository),
          ),
        ),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: getCategoryById,
          getJarById: getJarById,
        ),
        validateTags: ValidateTransactionTagsService(
          getTagsByIds: GetTagsByIdsUseCase(tagRepository),
        ),
        validateBudgets: validateBudgets,
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

      verify(
        () => validateBudgets(transaction, previous: transaction),
      ).called(1);

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

      verifyNever(
        () => validateBudgets(any(), previous: any(named: 'previous')),
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

      verifyNever(
        () => validateBudgets(any(), previous: any(named: 'previous')),
      );

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

      verifyNever(
        () => validateBudgets(any(), previous: any(named: 'previous')),
      );

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

      verify(
        () => validateBudgets(transaction, previous: transaction),
      ).called(1);

      verify(() => repository.update(transaction)).called(1);
    });

    test(
      'does not update when budget validation rejects the transaction',
      () async {
        final transaction = transactionFixture(id: 'budget-rejected');

        when(
          () => repository.getById(transaction.id),
        ).thenAnswer((_) async => Success<Transaction?>(transaction));

        const failure = TransactionWouldExceedBudgetFailure(
          message: 'Budget exceeded.',
        );

        when(
          () => validateBudgets(transaction, previous: transaction),
        ).thenAnswer((_) async => failure);

        final result = await service(transaction);

        expect(result.failureOrNull, same(failure));

        verify(
          () => validateBudgets(transaction, previous: transaction),
        ).called(1);

        verifyNever(() => repository.update(any()));
      },
    );

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
