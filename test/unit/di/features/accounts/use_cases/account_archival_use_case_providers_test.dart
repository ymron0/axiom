@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/archive_account_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_active_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_archived_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/unarchive_account_use_case.dart';
import 'package:axiom/src/features/accounts/di/archive_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:axiom/src/features/accounts/di/get_active_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_archived_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/unarchive_account_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('account archival use-case providers', () {
    test('resolves all archival use cases with the default repository', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
      );
      final lifecycleService = container.read(databaseLifecycleServiceProvider);
      addTearDown(() async {
        await lifecycleService.close();
        container.dispose();
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      // Then
      expect((await lifecycleService.open()).isSuccess, isTrue);
      expect(container.read(archiveAccountUseCaseProvider), isA<ArchiveAccountUseCase>());
      expect(container.read(unarchiveAccountUseCaseProvider), isA<UnarchiveAccountUseCase>());
      expect(container.read(getActiveAccountsUseCaseProvider), isA<GetActiveAccountsUseCase>());
      expect(container.read(getArchivedAccountsUseCaseProvider), isA<GetArchivedAccountsUseCase>());
    });

    test('forwards overridden dependencies', () async {
      // Given
      final repository = MockAccountRepository();
      final account = accountFixture(id: 'provider-account');
      when(() => repository.archive(account.id, timestamp)).thenAnswer(
        (_) async => Success(account),
      );
      when(() => repository.unarchive(account.id, timestamp)).thenAnswer(
        (_) async => Success(account),
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success([account]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success([account]),
      );
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );
      addTearDown(container.dispose);

      // When
      await container.read(archiveAccountUseCaseProvider)(account.id);
      await container.read(unarchiveAccountUseCaseProvider)(account.id);
      await container.read(getActiveAccountsUseCaseProvider)();
      await container.read(getArchivedAccountsUseCaseProvider)();

      // Then
      verify(() => repository.archive(account.id, timestamp)).called(1);
      verify(() => repository.unarchive(account.id, timestamp)).called(1);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'account-archival-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
