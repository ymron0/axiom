@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/create_account_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/delete_account_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/restore_account_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/search_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/update_account_use_case.dart';
import 'package:axiom/src/features/accounts/data/repositories/sembast_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/di/account_repository_provider.dart';
import 'package:axiom/src/features/accounts/di/create_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/delete_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/restore_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/search_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/update_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_command_fixtures.dart';
import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('account use-case providers', () {
    setUpAll(() {
      registerFallbackValue(accountFixture(id: 'fallback'));
    });

    test('resolves every use case from the default repository', () async {
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

      // When
      expect((await lifecycleService.open()).isSuccess, isTrue);
      final repository = container.read(accountRepositoryProvider);
      final useCases = [
        container.read(createAccountUseCaseProvider),
        container.read(getAccountsUseCaseProvider),
        container.read(getAccountByIdUseCaseProvider),
        container.read(getAccountsByCustodianIdUseCaseProvider),
        container.read(searchAccountsUseCaseProvider),
        container.read(updateAccountUseCaseProvider),
        container.read(deleteAccountUseCaseProvider),
        container.read(restoreAccountUseCaseProvider),
      ];

      // Then
      expect(repository, isA<SembastAccountRepositoryImpl>());
      expect(useCases, hasLength(8));
      expect(useCases[0], isA<CreateAccountUseCase>());
      expect(useCases[1], isA<GetAccountsUseCase>());
      expect(useCases[2], isA<GetAccountByIdUseCase>());
      expect(useCases[3], isA<GetAccountsByCustodianIdUseCase>());
      expect(useCases[4], isA<SearchAccountsUseCase>());
      expect(useCases[5], isA<UpdateAccountUseCase>());
      expect(useCases[6], isA<DeleteAccountUseCase>());
      expect(useCases[7], isA<RestoreAccountUseCase>());
    });

    test('injects an overridden repository into every use case', () async {
      // Given
      final repository = MockAccountRepository();
      final account = accountFixture(id: 'provider-account');
      final deleted = accountFixture(
        id: 'provider-deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      final accounts = [account];
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));
      when(
        () => repository.getById(account.id),
      ).thenAnswer((_) async => Success<Account?>(account));
      when(
        () => repository.getByCustodianId(account.custodianId),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));
      when(
        () => repository.search('account'),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));
      when(
        () => repository.update(account),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.delete(account.id),
      ).thenAnswer((_) async => Success(account));
      when(
        () => repository.restore(deleted),
      ).thenAnswer((_) async => const Success(null));
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 1, 1))),
        ],
      );
      addTearDown(container.dispose);

      // When
      final created = await container.read(createAccountUseCaseProvider)(
        createAccountCommandFixture(),
      );
      await container.read(getAccountsUseCaseProvider)();
      await container.read(getAccountByIdUseCaseProvider)(account.id);
      await container.read(getAccountsByCustodianIdUseCaseProvider)(
        account.custodianId,
      );
      await container.read(searchAccountsUseCaseProvider)('account');
      await container.read(updateAccountUseCaseProvider)(account);
      await container.read(deleteAccountUseCaseProvider)(account.id);
      await container.read(restoreAccountUseCaseProvider)(deleted);

      // Then
      verify(() => repository.create(created.valueOrNull!)).called(1);
      verify(() => repository.getAll()).called(1);
      verify(() => repository.getById(account.id)).called(1);
      verify(() => repository.getByCustodianId(account.custodianId)).called(1);
      verify(() => repository.search('account')).called(1);
      verify(() => repository.update(account)).called(1);
      verify(() => repository.delete(account.id)).called(1);
      verify(() => repository.restore(deleted)).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'account-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
