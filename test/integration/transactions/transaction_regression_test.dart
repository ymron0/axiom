@Tags(['integration'])
library;

import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/data/repositories/sembast_tag_repository_impl.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/application/services/allow_all_transaction_budgets_service.dart';
import '../../fixtures/application/services/allow_all_transaction_jar_balances_service.dart';
import '../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../fixtures/features/assets/asset_fixtures.dart';
import '../../mocks/asset_repository_mock.dart';
import '../../mocks/settings_repository_mock.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('Transaction regression', () {
    final timestamp = DateTime.utc(2026, 1, 1);
    final assetId = AssetId.fromString('asset-eur');

    setUpAll(() {
      registerFallbackValue(AssetId.fromString('fallback-asset'));
    });

    late SembastTransactionRepositoryImpl repository;
    late CreateTransactionService createService;
    late UpdateTransactionService updateService;

    setUp(() async {
      final sembastDatabase = await createTestSembastDatabase();
      final database = await sembastDatabase.open();

      repository = SembastTransactionRepositoryImpl(database: database);

      final categoryRepository = SembastCategoryRepositoryImpl(
        database: database,
      );

      final jarRepository = SembastJarRepositoryImpl(database: database);

      final tagRepository = SembastTagRepositoryImpl(database: database);

      final validateAllocations = ValidateTransactionAllocationsService(
        getCategoryById: GetCategoryByIdUseCase(categoryRepository),
        getJarById: GetJarByIdUseCase(jarRepository),
      );

      final validateTags = ValidateTransactionTagsService(
        getTagsByIds: GetTagsByIdsUseCase(tagRepository),
      );

      createService = CreateTransactionService(
        clock: FixedClock(timestamp),
        createTransaction: CreateTransactionUseCase(repository: repository),
        validateAssets: _assetValidator(assetId),
        validateAllocations: validateAllocations,
        validateTags: validateTags,
        validateBudgets: const AllowAllTransactionBudgetsService(),
        validateJarBalances: const AllowAllTransactionJarBalancesService(),
      );

      updateService = UpdateTransactionService(
        getTransactionById: GetTransactionByIdUseCase(repository),
        updateTransaction: UpdateTransactionUseCase(repository),
        validateAssets: _assetValidator(assetId),
        validateAllocations: validateAllocations,
        validateTags: validateTags,
        validateBudgets: const AllowAllTransactionBudgetsService(),
        validateJarBalances: const AllowAllTransactionJarBalancesService(),
      );
    });

    for (final kind in TransactionKind.values) {
      test('creates and persists an unallocated ${kind.name}', () async {
        final command = CreateTransactionCommand(
          kind: kind,
          merchantId: MerchantId.self,
          effectiveAt: timestamp,
          description: kind.name,
          state: TransactionState.actual,
          splits: const [],
          ledgerEntries: _ledgerEntriesFor(kind),
        );

        final result = await createService(command);

        expect(result.isSuccess, isTrue);

        final transaction = result.valueOrNull!;

        expect(transaction.kind, kind);
        expect(transaction.splits, isEmpty);

        final persisted = (await repository.getById(
          transaction.id,
        )).valueOrNull;

        expect(persisted, isNotNull);
        expect(persisted!.id, transaction.id);
        expect(persisted.kind, transaction.kind);
        expect(persisted.description, transaction.description);
        expect(persisted.splits, isEmpty);
      });
    }

    test('updates and persists an unallocated transaction', () async {
      final created = (await createService(
        CreateTransactionCommand(
          kind: TransactionKind.expense,
          merchantId: MerchantId.self,
          effectiveAt: timestamp,
          description: 'Original',
          state: TransactionState.actual,
          splits: const [],
          ledgerEntries: _ledgerEntriesFor(TransactionKind.expense),
        ),
      )).valueOrNull!;

      final updated = created.copyWith(description: 'Updated');

      final result = await updateService(updated);

      expect(result.isSuccess, isTrue);

      final persisted = (await repository.getById(created.id)).valueOrNull!;

      expect(persisted.description, 'Updated');
      expect(persisted.splits, isEmpty);
      expect(persisted.ledgerEntries, hasLength(1));

      expect(
        persisted.ledgerEntries.single.accountId.value,
        created.ledgerEntries.single.accountId.value,
      );
    });
  });
}

List<LedgerEntry> _ledgerEntriesFor(TransactionKind kind) {
  final outgoing = _amount(incoming: false);
  final incoming = _amount(incoming: true);

  return switch (kind) {
    TransactionKind.expense => [_entry('account-expense', outgoing)],
    TransactionKind.income => [_entry('account-income', incoming)],
    TransactionKind.balanceCorrection => [
      _entry('account-correction', outgoing),
    ],
    TransactionKind.transfer => [
      _entry('account-from', outgoing),
      _entry('account-to', incoming),
    ],
  };
}

LedgerEntry _entry(String accountId, AssetAmount amount) {
  return LedgerEntry(
    accountId: AccountId.fromString(accountId),
    transactionAmount: amount,
    accountAmount: amount,
    valuationAmount: amount,
    role: LedgerEntryRole.primary,
  );
}

AssetAmount _amount({required bool incoming}) {
  final assetId = AssetId.fromString('asset-eur');
  final amount = Decimal.fromInt(10);

  return incoming
      ? AssetAmount.incoming(assetId: assetId, amount: amount)
      : AssetAmount.outgoing(assetId: assetId, amount: amount);
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
