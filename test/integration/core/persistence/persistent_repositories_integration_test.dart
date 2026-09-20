@Tags(['integration', 'core', 'persistence', 'repositories'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/accounts/data/repositories/sembast_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:axiom/src/features/assets/data/repositories/sembast_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/failures/category_repository_failure.dart';
import 'package:axiom/src/features/custodians/data/repositories/sembast_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_repository_failure.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_repository_failure.dart';
import 'package:axiom/src/features/merchants/data/repositories/sembast_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_repository_failure.dart';
import 'package:axiom/src/features/rates/data/repositories/sembast_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('Persistent repositories integration', () {
    test(
      'all persistent repositories survive physical close and application restart',
      () async {
        // Given
        //
        // Use the real IO-backed Sembast factory. This test deliberately does
        // not use databaseFactoryMemory because the contract being verified is
        // persistence across an actual close/reopen boundary.
        final environment = await PersistenceTestEnvironment.createIo(
          prefix: 'persistent-repository-round-trip-',
        );

        final firstLifecycle = environment.createLifecycle();

        final firstOpenResult = await firstLifecycle.open();

        expect(firstOpenResult.isSuccess, isTrue);
        expect(firstOpenResult.failureOrNull, isNull);

        final firstDatabase = firstOpenResult.valueOrNull!;

        expect(firstDatabase.version, DatabaseSchema.version);
        expect(await environment.databaseFile.exists(), isTrue);

        final firstRepositories = _PersistentRepositories(firstDatabase);

        // Use deterministic fixtures so equality after reconstruction verifies
        // that persistence models preserve complete domain state rather than
        // merely proving that records exist.
        final euro = currencyFixture(
          id: 'asset-eur',
          name: 'Euro',
          code: 'EUR',
        );

        final usd = currencyFixture(
          id: 'asset-usd',
          name: 'US Dollar',
          code: 'USD',
        );

        final settings = Settings(valuationCurrencyId: euro.id);

        final rate = exchangeRateFixture(
          id: 'rate-eur-usd',
          baseAssetId: euro.id.value,
          quoteAssetId: usd.id.value,
          rate: '1.08',
          effectiveAt: DateTime.utc(2026, 9, 15, 12),
        );

        // MerchantId.self is a reserved non-persisted transaction reference,
        // so use a regular ID for the persisted merchant representative.
        final merchant = merchantFixture(
          id: 'merchant-integration',
          name: 'Integration Merchant',
        );

        final custodian = custodianFixture(
          id: 'custodian-bank',
          name: 'Integration Bank',
        );

        // The transaction fixture uses account-eur and asset-eur.
        final account = accountFixture(
          id: 'account-eur',
          name: 'EUR Current Account',
          custodianId: custodian.id.value,
          denominationAssetId: euro.id.value,
        );

        final category = categoryFixture(id: 'category-food', name: 'Food');

        final jar = jarFixture(id: 'jar-travel', name: 'Travel');

        final transaction = transactionFixture(
          id: 'transaction-1',
          effectiveAt: DateTime.utc(2026, 9, 15, 18),
        );

        // When
        //
        // Persist one representative aggregate through every S8 repository.
        final createEuroResult = await firstRepositories.assets.create(euro);
        final createUsdResult = await firstRepositories.assets.create(usd);
        final createSettingsResult = await firstRepositories.settings.create(
          settings,
        );
        final createRateResult = await firstRepositories.rates.create(rate);
        final createMerchantResult = await firstRepositories.merchants.create(
          merchant,
        );
        final createCustodianResult = await firstRepositories.custodians.create(
          custodian,
        );
        final createAccountResult = await firstRepositories.accounts.create(
          account,
        );
        final createCategoryResult = await firstRepositories.categories.create(
          category,
        );
        final createJarResult = await firstRepositories.jars.create(jar);
        final createTransactionResult = await firstRepositories.transactions
            .create(transaction);

        // Then: every write succeeded before shutdown.
        expect(createEuroResult.isSuccess, isTrue);
        expect(createUsdResult.isSuccess, isTrue);
        expect(createSettingsResult.isSuccess, isTrue);
        expect(createRateResult.isSuccess, isTrue);
        expect(createMerchantResult.isSuccess, isTrue);
        expect(createCustodianResult.isSuccess, isTrue);
        expect(createAccountResult.isSuccess, isTrue);
        expect(createCategoryResult.isSuccess, isTrue);
        expect(createJarResult.isSuccess, isTrue);
        expect(createTransactionResult.isSuccess, isTrue);

        // When
        //
        // Close the entire production lifecycle. No live Database or repository
        // object is reused after this point.
        final firstCloseResult = await firstLifecycle.close();

        expect(firstCloseResult.isSuccess, isTrue);
        expect(firstLifecycle.isOpen, isFalse);
        expect(await environment.databaseFile.exists(), isTrue);

        // Construct a completely new lifecycle and completely new repository
        // instances against the same physical database file. This represents a
        // process/application restart at the persistence boundary.
        final secondLifecycle = environment.createLifecycle();

        final secondOpenResult = await secondLifecycle.open();

        expect(secondOpenResult.isSuccess, isTrue);
        expect(secondOpenResult.failureOrNull, isNull);
        expect(secondLifecycle.isOpen, isTrue);

        final secondDatabase = secondOpenResult.valueOrNull!;

        expect(secondDatabase.version, DatabaseSchema.version);

        final secondRepositories = _PersistentRepositories(secondDatabase);

        // Then
        //
        // Read every aggregate back through its public repository API.
        final persistedEuroResult = await secondRepositories.assets.getById(
          euro.id,
        );
        final persistedUsdResult = await secondRepositories.assets.getById(
          usd.id,
        );
        final persistedSettingsResult = await secondRepositories.settings.get();
        final persistedRateResult = await secondRepositories.rates.getById(
          rate.id,
        );
        final persistedMerchantResult = await secondRepositories.merchants
            .getById(merchant.id);
        final persistedCustodianResult = await secondRepositories.custodians
            .getById(custodian.id);
        final persistedAccountResult = await secondRepositories.accounts
            .getById(account.id);
        final persistedCategoryResult = await secondRepositories.categories
            .getById(category.id);
        final persistedJarResult = await secondRepositories.jars.getById(
          jar.id,
        );
        final persistedTransactionResult = await secondRepositories.transactions
            .getById(transaction.id);

        expect(persistedEuroResult.isSuccess, isTrue);
        expect(persistedEuroResult.valueOrNull, equals(euro));

        expect(persistedUsdResult.isSuccess, isTrue);
        expect(persistedUsdResult.valueOrNull, equals(usd));

        expect(persistedSettingsResult.isSuccess, isTrue);
        expect(persistedSettingsResult.valueOrNull, equals(settings));

        expect(persistedRateResult.isSuccess, isTrue);
        expect(persistedRateResult.valueOrNull, equals(rate));

        expect(persistedMerchantResult.isSuccess, isTrue);
        expect(persistedMerchantResult.valueOrNull, equals(merchant));

        expect(persistedCustodianResult.isSuccess, isTrue);
        expect(persistedCustodianResult.valueOrNull, equals(custodian));

        expect(persistedAccountResult.isSuccess, isTrue);
        expect(persistedAccountResult.valueOrNull, equals(account));

        expect(persistedCategoryResult.isSuccess, isTrue);
        expect(persistedCategoryResult.valueOrNull, equals(category));

        expect(persistedJarResult.isSuccess, isTrue);
        expect(persistedJarResult.valueOrNull, equals(jar));

        expect(persistedTransactionResult.isSuccess, isTrue);
        expect(persistedTransactionResult.valueOrNull, equals(transaction));
      },
    );

    test(
      'malformed records become feature-specific persistence failures',
      () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo(
          prefix: 'persistent-repository-malformed-records-',
        );

        // Deliberately bypass repositories and the production lifecycle to
        // prepare persisted state that could not normally be written through
        // the application.
        final rawDatabase = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        const malformedRecord = <String, Object?>{'unexpected': 'record-shape'};

        const corruptAssetId = 'corrupt-asset';
        const corruptRateId = 'corrupt-rate';
        const corruptMerchantId = 'corrupt-merchant';
        const corruptTransactionId = 'corrupt-transaction';
        const corruptAccountId = 'corrupt-account';
        const corruptCustodianId = 'corrupt-custodian';
        const corruptCategoryId = 'corrupt-category';
        const corruptJarId = 'corrupt-jar';

        await SembastStores.assets
            .record(corruptAssetId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.settings
            .record(SembastRecordKeys.settings)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.rates
            .record(corruptRateId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.merchants
            .record(corruptMerchantId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.transactions
            .record(corruptTransactionId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.accounts
            .record(corruptAccountId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.custodians
            .record(corruptCustodianId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.categories
            .record(corruptCategoryId)
            .put(rawDatabase.database, malformedRecord);

        await SembastStores.jars
            .record(corruptJarId)
            .put(rawDatabase.database, malformedRecord);

        await rawDatabase.close();

        // When
        //
        // DatabaseIntegrityChecker performs structural database validation,
        // not complete domain-record deserialization. The database itself is
        // therefore expected to open successfully.
        final lifecycle = environment.createLifecycle();

        final openResult = await lifecycle.open();

        // Then
        expect(
          openResult.isSuccess,
          isTrue,
          reason:
              'Database integrity validation is structural; malformed domain '
              'records must be handled by repository persistence boundaries.',
        );

        expect(lifecycle.isOpen, isTrue);

        final repositories = _PersistentRepositories(openResult.valueOrNull!);

        // When / Then
        //
        // Each repository reconstructs its own persistence model. The malformed
        // record must never leak PersistenceRecordException or raw Sembast
        // exceptions to callers.
        final assetResult = await repositories.assets.getById(
          AssetId.fromString(corruptAssetId),
        );

        expect(assetResult.isFailure, isTrue);
        expect(assetResult.valueOrNull, isNull);
        expect(assetResult.failureOrNull, isA<AssetRepositoryFailure>());

        final settingsResult = await repositories.settings.get();

        expect(settingsResult.isFailure, isTrue);
        expect(settingsResult.valueOrNull, isNull);
        expect(settingsResult.failureOrNull, isA<SettingsRepositoryFailure>());

        final rateResult = await repositories.rates.getById(
          RateId.fromString(corruptRateId),
        );

        expect(rateResult.isFailure, isTrue);
        expect(rateResult.valueOrNull, isNull);
        expect(rateResult.failureOrNull, isA<RateRepositoryFailure>());

        final merchantResult = await repositories.merchants.getById(
          MerchantId.fromString(corruptMerchantId),
        );

        expect(merchantResult.isFailure, isTrue);
        expect(merchantResult.valueOrNull, isNull);
        expect(merchantResult.failureOrNull, isA<MerchantRepositoryFailure>());

        final transactionResult = await repositories.transactions.getById(
          TransactionId.fromString(corruptTransactionId),
        );

        expect(transactionResult.isFailure, isTrue);
        expect(transactionResult.valueOrNull, isNull);
        expect(
          transactionResult.failureOrNull,
          isA<TransactionRepositoryFailure>(),
        );

        final accountResult = await repositories.accounts.getById(
          AccountId.fromString(corruptAccountId),
        );

        expect(accountResult.isFailure, isTrue);
        expect(accountResult.valueOrNull, isNull);
        expect(accountResult.failureOrNull, isA<AccountRepositoryFailure>());

        final custodianResult = await repositories.custodians.getById(
          CustodianId.fromString(corruptCustodianId),
        );

        expect(custodianResult.isFailure, isTrue);
        expect(custodianResult.valueOrNull, isNull);
        expect(
          custodianResult.failureOrNull,
          isA<CustodianRepositoryFailure>(),
        );

        final categoryResult = await repositories.categories.getById(
          CategoryId.fromString(corruptCategoryId),
        );

        expect(categoryResult.isFailure, isTrue);
        expect(categoryResult.valueOrNull, isNull);
        expect(categoryResult.failureOrNull, isA<CategoryRepositoryFailure>());

        final jarResult = await repositories.jars.getById(
          JarId.fromString(corruptJarId),
        );

        expect(jarResult.isFailure, isTrue);
        expect(jarResult.valueOrNull, isNull);
        expect(jarResult.failureOrNull, isA<JarRepositoryFailure>());

        // Repository-level corruption must not cause database replacement or
        // lifecycle shutdown.
        expect(lifecycle.isOpen, isTrue);
        expect(await environment.databaseFile.exists(), isTrue);
      },
    );
  });
}

/// Groups the concrete persistent repositories bound to one validated database.
///
/// This fixture intentionally constructs the production repository
/// implementations directly.
///
/// S8.12 is verifying the persistence implementations themselves. DI/provider
/// wiring belongs to the provider tests and should not be required for these
/// database integration tests.
final class _PersistentRepositories {
  final SembastAssetRepositoryImpl assets;
  final SembastSettingsRepositoryImpl settings;
  final SembastRateRepositoryImpl rates;
  final SembastMerchantRepositoryImpl merchants;
  final SembastTransactionRepositoryImpl transactions;
  final SembastAccountRepositoryImpl accounts;
  final SembastCustodianRepositoryImpl custodians;
  final SembastCategoryRepositoryImpl categories;
  final SembastJarRepositoryImpl jars;

  _PersistentRepositories(Database database)
    : assets = SembastAssetRepositoryImpl(database: database),
      settings = SembastSettingsRepositoryImpl(database: database),
      rates = SembastRateRepositoryImpl(database: database),
      merchants = SembastMerchantRepositoryImpl(database: database),
      transactions = SembastTransactionRepositoryImpl(database: database),
      accounts = SembastAccountRepositoryImpl(database: database),
      custodians = SembastCustodianRepositoryImpl(database: database),
      categories = SembastCategoryRepositoryImpl(database: database),
      jars = SembastJarRepositoryImpl(database: database);
}
