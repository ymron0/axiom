@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/archive_account_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_active_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_archived_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/application/use_cases/unarchive_account_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('account archival use cases', () {
    late MockAccountRepository repository;
    late ArchiveAccountUseCase archive;
    late UnarchiveAccountUseCase unarchive;

    setUpAll(() {
      registerFallbackValue(AccountId.fromString('fallback-account'));
    });

    setUp(() {
      repository = MockAccountRepository();
      final clock = FixedClock(timestamp);
      archive = ArchiveAccountUseCase(repository: repository, clock: clock);
      unarchive = UnarchiveAccountUseCase(
        repository: repository,
        clock: clock,
      );
    });

    test('archive and unarchive forward the canonical timestamp', () async {
      // Given
      final account = accountFixture(id: 'account');
      when(() => repository.archive(account.id, timestamp)).thenAnswer(
        (_) async => Success(account),
      );
      when(() => repository.unarchive(account.id, timestamp)).thenAnswer(
        (_) async => Success(account),
      );

      // When
      await archive(account.id);
      await unarchive(account.id);

      // Then
      verify(() => repository.archive(account.id, timestamp)).called(1);
      verify(() => repository.unarchive(account.id, timestamp)).called(1);
    });

    test('active and archived queries delegate unchanged', () async {
      // Given
      final active = accountFixture(id: 'active');
      final archived = accountFixture(id: 'archived');
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success<List<Account>>([active]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success<List<Account>>([archived]),
      );

      // When
      final activeResult = await GetActiveAccountsUseCase(repository)();
      final archivedResult = await GetArchivedAccountsUseCase(repository)();

      // Then
      expect(activeResult.valueOrNull, [active]);
      expect(archivedResult.valueOrNull, [archived]);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = AccountNotFoundFailure(message: 'not found');
      when(() => repository.archive(any(), timestamp)).thenAnswer(
        (_) async => failure,
      );
      when(() => repository.getActive()).thenAnswer((_) async => failure);

      // When
      final archiveResult = await archive(accountFixture(id: 'missing').id);
      final activeResult = await GetActiveAccountsUseCase(repository)();

      // Then
      expect(archiveResult.failureOrNull, same(failure));
      expect(activeResult.failureOrNull, same(failure));
    });
  });
}
