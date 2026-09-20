@Tags(['integration'])
library;

import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/data/repositories/sembast_tag_repository_impl.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/application/services/allow_all_transaction_budgets_service.dart';
import '../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../fixtures/features/categories/category_fixtures.dart';
import '../../fixtures/features/jars/jar_fixtures.dart';
import '../../fixtures/features/assets/asset_fixtures.dart';
import '../../mocks/asset_repository_mock.dart';
import '../../mocks/settings_repository_mock.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('Transaction jar and category allocation workflow', () {
    final timestamp = DateTime.utc(2026, 1, 1);
    final assetId = AssetId.fromString('asset-eur');

    setUpAll(() {
      registerFallbackValue(AssetId.fromString('fallback-asset'));
    });

    final expenseCategory = categoryFixture(id: 'groceries');

    final incomeCategory = categoryFixture(
      id: 'salary',
      kind: CategoryKind.income,
    );

    final jarId = JarId.fromString('monthly-budget');

    late SembastTransactionRepositoryImpl transactionRepository;
    late CreateTransactionService service;

    setUp(() async {
      final sembastDatabase = await createTestSembastDatabase();
      final database = await sembastDatabase.open();

      final categoryRepository = SembastCategoryRepositoryImpl(
        database: database,
      );

      await categoryRepository.create(expenseCategory);
      await categoryRepository.create(incomeCategory);

      final jarRepository = SembastJarRepositoryImpl(database: database);

      await jarRepository.create(jarFixture(id: jarId.value));

      final tagRepository = SembastTagRepositoryImpl(database: database);

      transactionRepository = SembastTransactionRepositoryImpl(
        database: database,
      );

      service = CreateTransactionService(
        clock: FixedClock(timestamp),
        createTransaction: CreateTransactionUseCase(
          repository: transactionRepository,
        ),
        validateAssets: _assetValidator(assetId),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: GetCategoryByIdUseCase(categoryRepository),
          getJarById: GetJarByIdUseCase(jarRepository),
        ),
        validateTags: ValidateTransactionTagsService(
          getTagsByIds: GetTagsByIdsUseCase(tagRepository),
        ),
        validateBudgets: const AllowAllTransactionBudgetsService(),
      );
    });

    CreateTransactionCommand command({
      required TransactionKind kind,
      CategoryId? categoryId,
      JarId? allocationJarId,
    }) {
      final direction = kind == TransactionKind.income
          ? AssetAmountDirection.incoming
          : AssetAmountDirection.outgoing;

      final amount = AssetAmount(
        assetId: assetId,
        amount: Decimal.fromInt(10),
        direction: direction,
      );

      return CreateTransactionCommand(
        kind: kind,
        merchantId: MerchantId.self,
        effectiveAt: timestamp,
        description: 'Allocated transaction',
        state: TransactionState.actual,
        splits: [
          TransactionSplit(
            transactionAmount: amount,
            valuationAmount: amount,
            categoryId: categoryId,
            jarId: allocationJarId,
          ),
        ],
        ledgerEntries: [
          LedgerEntry(
            accountId: AccountId.fromString('account-eur'),
            transactionAmount: amount,
            accountAmount: amount,
            valuationAmount: amount,
            role: LedgerEntryRole.primary,
          ),
        ],
      );
    }

    test(
      'persists expense and income transactions with jar allocations',
      () async {
        final commands = [
          command(kind: TransactionKind.expense, allocationJarId: jarId),
          command(kind: TransactionKind.income, allocationJarId: jarId),
        ];

        final results = [
          for (final createCommand in commands) await service(createCommand),
        ];

        expect(results, everyElement(isA<Success<Transaction>>()));

        expect(
          results.map((result) => result.valueOrNull!.splits.single.jarId),
          everyElement(jarId),
        );

        expect(
          (await transactionRepository.getAll()).valueOrNull,
          hasLength(2),
        );
      },
    );

    test(
      'persists expense and income transactions with valid categories',
      () async {
        final commands = [
          command(
            kind: TransactionKind.expense,
            categoryId: expenseCategory.id,
          ),
          command(kind: TransactionKind.income, categoryId: incomeCategory.id),
        ];

        final results = [
          for (final createCommand in commands) await service(createCommand),
        ];

        expect(results, everyElement(isA<Success<Transaction>>()));

        expect(
          (await transactionRepository.getAll()).valueOrNull,
          hasLength(2),
        );
      },
    );

    test('persists both allocation dimensions together', () async {
      final createCommand = command(
        kind: TransactionKind.expense,
        categoryId: expenseCategory.id,
        allocationJarId: jarId,
      );

      final result = await service(createCommand);

      expect(result.isSuccess, isTrue);

      final transaction = result.valueOrNull!;

      expect(transaction.splits.single.categoryId, expenseCategory.id);

      expect(transaction.splits.single.jarId, jarId);

      final persisted = (await transactionRepository.getById(
        transaction.id,
      )).valueOrNull;

      expect(persisted, isNotNull);
      expect(persisted!.id, transaction.id);
      expect(persisted.kind, transaction.kind);

      expect(
        persisted.splits.single.categoryId,
        transaction.splits.single.categoryId,
      );

      expect(persisted.splits.single.jarId, transaction.splits.single.jarId);
    });

    test(
      'rejects missing categories but accepts opposite-kind allocations',
      () async {
        final missingCategoryCommand = command(
          kind: TransactionKind.expense,
          categoryId: CategoryId.fromString('missing'),
        );

        final oppositeKindCommand = command(
          kind: TransactionKind.expense,
          categoryId: incomeCategory.id,
        );

        final missingResult = await service(missingCategoryCommand);

        final oppositeKindResult = await service(oppositeKindCommand);

        expect(
          missingResult.failureOrNull,
          isA<AllocationCategoryNotFoundFailure>(),
        );

        expect(oppositeKindResult.isSuccess, isTrue);

        final persisted = (await transactionRepository.getAll()).valueOrNull!;

        expect(persisted, hasLength(1));

        expect(persisted.single.splits.single.categoryId, incomeCategory.id);
      },
    );
  });
}

ValidateTransactionAssetSemanticsService _assetValidator(
  AssetId valuationCurrencyId,
) {
  final assetRepository = MockAssetRepository();
  final settingsRepository = MockSettingsRepository();

  when(() => settingsRepository.get()).thenAnswer(
    (_) async => Success(Settings(valuationCurrencyId: valuationCurrencyId)),
  );
  when(() => assetRepository.getById(any())).thenAnswer((invocation) async {
    final assetId = invocation.positionalArguments.single as AssetId;
    return Success(currencyFixture(id: assetId.value));
  });
  when(() => assetRepository.getByIds(any())).thenAnswer((invocation) async {
    final ids = invocation.positionalArguments.single as List<AssetId>;
    return Success(
      BatchLookup(
        found: [for (final id in ids) currencyFixture(id: id.value)],
        missing: const [],
      ),
    );
  });

  return ValidateTransactionAssetSemanticsService(
    getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
    getValuationCurrency: GetValuationCurrencyService(
      getSettings: GetSettingsUseCase(settingsRepository),
      getAssetById: GetAssetByIdUseCase(assetRepository),
    ),
  );
}
