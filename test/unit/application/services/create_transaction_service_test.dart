@Tags(['application'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
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
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_command_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';
import '../../../mocks/validate_transaction_budgets_service_mock.dart';

void main() {
  group('CreateTransactionService', () {
    late MockTransactionRepository repository;
    late MockAssetRepository assetRepository;
    late MockSettingsRepository settingsRepository;
    late MockTagRepository tagRepository;
    late MockGetCategoryByIdUseCase getCategoryById;
    late MockGetJarByIdUseCase getJarById;
    late MockValidateTransactionBudgetsService validateBudgets;
    late CreateTransactionService service;

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
        () => validateBudgets(any()),
      ).thenAnswer((_) async => const Success(null));

      service = CreateTransactionService(
        clock: FixedClock(DateTime.utc(2026, 1, 1)),
        createTransaction: CreateTransactionUseCase(repository: repository),
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

        verify(() => validateBudgets(transaction)).called(1);

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

      verifyNever(() => validateBudgets(any()));

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

      verifyNever(() => validateBudgets(any()));

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

      verify(() => validateBudgets(any())).called(1);

      verify(() => repository.create(any())).called(1);
    });

    test(
      'does not persist when budget validation rejects the transaction',
      () async {
        final command = createTransactionCommandFixture();

        const failure = TransactionWouldExceedBudgetFailure(
          message: 'Budget exceeded.',
        );

        when(() => validateBudgets(any())).thenAnswer((_) async => failure);

        final result = await service(command);

        expect(result.failureOrNull, same(failure));

        verify(() => validateBudgets(any())).called(1);

        verifyNever(() => repository.create(any()));
      },
    );

    test('propagates persistence failures', () async {
      final command = createTransactionCommandFixture();

      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');

      when(() => repository.create(any())).thenAnswer((_) async => failure);

      final result = await service(command);

      expect(result.failureOrNull, same(failure));
    });
  });
}
