@Tags(['integration'])
library;

import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/application/use_cases/update_settings_use_case.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/data/repositories/sembast_tag_repository_impl.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/application/services/allow_all_transaction_jar_balances_service.dart';
import '../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../fixtures/features/assets/asset_fixtures.dart';
import '../../mocks/asset_repository_mock.dart';

void main() {
  group('Transaction budget enforcement setting', () {
    final chf = AssetId.fromString('asset-chf');
    final effectiveAt = DateTime.utc(2026, 1, 15);

    setUpAll(() {
      registerFallbackValue(AssetId.fromString('fallback-asset'));
    });

    test('rejects overbudget transactions when disabled and accepts them '
        'after the setting is enabled', () async {
      final sembastDatabase = await createTestSembastDatabase();

      final database = await sembastDatabase.open();

      final settingsRepository = SembastSettingsRepositoryImpl(
        database: database,
      );

      final categoryRepository = SembastCategoryRepositoryImpl(
        database: database,
      );

      final transactionRepository = SembastTransactionRepositoryImpl(
        database: database,
      );

      final jarRepository = SembastJarRepositoryImpl(database: database);

      final tagRepository = SembastTagRepositoryImpl(database: database);

      final initialSettings = Settings(
        valuationCurrencyId: chf,
        allowOverbudgetTransactions: false,
      );

      final createSettingsResult = await settingsRepository.create(
        initialSettings,
      );

      expect(createSettingsResult.isSuccess, isTrue);

      final category = Category(
        id: CategoryId.fromString('groceries'),
        name: 'Groceries',
        kind: CategoryKind.expense,
        budgets: [
          CategoryBudget(
            limit: AssetAmount.incoming(
              assetId: chf,
              amount: Decimal.parse('100'),
            ),
            period: BudgetPeriod.monthly,
            effectiveFrom: CalendarDate(2026, 1, 1),
          ),
        ],
        icon: EntityIcon.other,
        color: EntityColor.blue,
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        entityVersion: 1,
      );

      expect((await categoryRepository.create(category)).isSuccess, isTrue);

      final getSettings = GetSettingsUseCase(settingsRepository);

      final service = CreateTransactionService(
        clock: FixedClock(effectiveAt),
        createTransaction: CreateTransactionUseCase(
          repository: transactionRepository,
        ),
        validateAssets: _assetValidator(
          valuationCurrencyId: chf,
          getSettings: getSettings,
        ),
        validateAllocations: ValidateTransactionAllocationsService(
          getCategoryById: GetCategoryByIdUseCase(categoryRepository),
          getJarById: GetJarByIdUseCase(jarRepository),
        ),
        validateTags: ValidateTransactionTagsService(
          getTagsByIds: GetTagsByIdsUseCase(tagRepository),
        ),
        validateBudgets: ValidateTransactionBudgetsService(
          getSettings: getSettings,
          getCategories: GetCategoriesUseCase(categoryRepository),
          queryTransactions: QueryTransactionsUseCase(transactionRepository),
          calculator: const CategorySpendingCalculator(),
        ),
        validateJarBalances: const AllowAllTransactionJarBalancesService(),
      );

      final firstResult = await service(
        _expenseCommand(
          categoryId: category.id,
          assetId: chf,
          amount: '60',
          effectiveAt: effectiveAt,
        ),
      );

      expect(firstResult.isSuccess, isTrue);

      final rejectedResult = await service(
        _expenseCommand(
          categoryId: category.id,
          assetId: chf,
          amount: '50',
          effectiveAt: effectiveAt,
        ),
      );

      expect(
        rejectedResult.failureOrNull,
        isA<TransactionWouldExceedBudgetFailure>(),
      );

      expect((await transactionRepository.getAll()).valueOrNull, hasLength(1));

      final updateSettings = UpdateSettingsUseCase(settingsRepository);

      final permissiveSettings = initialSettings.copyWith(
        allowOverbudgetTransactions: true,
      );

      final settingsResult = await updateSettings(permissiveSettings);

      expect(settingsResult.isSuccess, isTrue);

      final allowedResult = await service(
        _expenseCommand(
          categoryId: category.id,
          assetId: chf,
          amount: '50',
          effectiveAt: effectiveAt,
        ),
      );

      expect(allowedResult.isSuccess, isTrue);

      expect((await transactionRepository.getAll()).valueOrNull, hasLength(2));
    });
  });
}

CreateTransactionCommand _expenseCommand({
  required CategoryId categoryId,
  required AssetId assetId,
  required String amount,
  required DateTime effectiveAt,
}) {
  final value = AssetAmount.outgoing(
    assetId: assetId,
    amount: Decimal.parse(amount),
  );

  return CreateTransactionCommand(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    description: 'Budgeted expense',
    state: TransactionState.actual,
    splits: [
      TransactionSplit(
        transactionAmount: value,
        valuationAmount: value,
        categoryId: categoryId,
      ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-chf'),
        transactionAmount: value,
        accountAmount: value,
        valuationAmount: value,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}

ValidateTransactionAssetSemanticsService _assetValidator({
  required AssetId valuationCurrencyId,
  required GetSettingsUseCase getSettings,
}) {
  final assetRepository = MockAssetRepository();

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
      getSettings: getSettings,
      getAssetById: GetAssetByIdUseCase(assetRepository),
    ),
  );
}
