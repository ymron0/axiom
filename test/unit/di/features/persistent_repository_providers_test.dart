@Tags(['di', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/features/accounts/data/repositories/sembast_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:axiom/src/features/assets/data/repositories/sembast_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:axiom/src/features/custodians/data/repositories/sembast_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:axiom/src/features/merchants/data/repositories/sembast_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/di/merchant_repository_provider.dart';
import 'package:axiom/src/features/rates/data/repositories/sembast_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_series_repository_impl.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('persistent repository providers', () {
    late String rootPath;
    late Directory rootDirectory;
    late ProviderContainer container;

    setUp(() async {
      rootPath = _uniqueRootPath();
      rootDirectory = Directory(rootPath);

      container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
      );

      final lifecycleService = container.read(databaseLifecycleServiceProvider);

      final openResult = await lifecycleService.open();

      expect(
        openResult.isSuccess,
        isTrue,
        reason:
            'Persistent repository providers require a successfully opened '
            'and validated database.',
      );
    });

    tearDown(() async {
      final lifecycleService = container.read(databaseLifecycleServiceProvider);

      await lifecycleService.close();

      container.dispose();

      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    test('resolves every domain repository to its Sembast implementation', () {
      // When
      final assetRepository = container.read(assetRepositoryProvider);
      final settingsRepository = container.read(settingsRepositoryProvider);
      final rateRepository = container.read(rateRepositoryProvider);
      final transactionRepository = container.read(
        transactionRepositoryProvider,
      );
      final transactionSeriesRepository = container.read(
        transactionSeriesRepositoryProvider,
      );
      final merchantRepository = container.read(merchantRepositoryProvider);
      final accountRepository = container.read(accountRepositoryProvider);
      final custodianRepository = container.read(custodianRepositoryProvider);
      final categoryRepository = container.read(categoryRepositoryProvider);
      final jarRepository = container.read(jarRepositoryProvider);

      // Then
      expect(assetRepository, isA<SembastAssetRepositoryImpl>());
      expect(settingsRepository, isA<SembastSettingsRepositoryImpl>());
      expect(rateRepository, isA<SembastRateRepositoryImpl>());
      expect(transactionRepository, isA<SembastTransactionRepositoryImpl>());
      expect(
        transactionSeriesRepository,
        isA<SembastTransactionSeriesRepositoryImpl>(),
      );
      expect(merchantRepository, isA<SembastMerchantRepositoryImpl>());
      expect(accountRepository, isA<SembastAccountRepositoryImpl>());
      expect(custodianRepository, isA<SembastCustodianRepositoryImpl>());
      expect(categoryRepository, isA<SembastCategoryRepositoryImpl>());
      expect(jarRepository, isA<SembastJarRepositoryImpl>());
    });

    test('keeps repository instances alive for the container lifetime', () {
      // When / Then
      expect(
        container.read(assetRepositoryProvider),
        same(container.read(assetRepositoryProvider)),
      );
      expect(
        container.read(settingsRepositoryProvider),
        same(container.read(settingsRepositoryProvider)),
      );
      expect(
        container.read(rateRepositoryProvider),
        same(container.read(rateRepositoryProvider)),
      );
      expect(
        container.read(transactionRepositoryProvider),
        same(container.read(transactionRepositoryProvider)),
      );
      expect(
        container.read(transactionSeriesRepositoryProvider),
        same(container.read(transactionSeriesRepositoryProvider)),
      );
      expect(
        container.read(merchantRepositoryProvider),
        same(container.read(merchantRepositoryProvider)),
      );
      expect(
        container.read(accountRepositoryProvider),
        same(container.read(accountRepositoryProvider)),
      );
      expect(
        container.read(custodianRepositoryProvider),
        same(container.read(custodianRepositoryProvider)),
      );
      expect(
        container.read(categoryRepositoryProvider),
        same(container.read(categoryRepositoryProvider)),
      );
      expect(
        container.read(jarRepositoryProvider),
        same(container.read(jarRepositoryProvider)),
      );
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'persistent-repository-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
