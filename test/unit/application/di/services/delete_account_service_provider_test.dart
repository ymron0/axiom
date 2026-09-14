@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/delete_account_service_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/delete_account_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_account_id_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../mocks/delete_account_use_case_mock.dart';
import '../../../../mocks/transactions_exist_by_account_id_use_case_mock.dart';

void main() {
  group('deleteAccountServiceProvider', () {
    test('uses the configured transaction check and account deletion', () async {
      // Given
      final transactionsExist = MockTransactionsExistByAccountIdUseCase();
      final deleteAccount = MockDeleteAccountUseCase();
      final account = accountFixture(
        id: 'provider-account',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => transactionsExist(account.id),
      ).thenAnswer((_) async => const Success(false));
      when(
        () => deleteAccount(account.id),
      ).thenAnswer((_) async => Success<Account>(account));
      final container = ProviderContainer(
        overrides: [
          transactionsExistByAccountIdUseCaseProvider.overrideWithValue(
            transactionsExist,
          ),
          deleteAccountUseCaseProvider.overrideWithValue(deleteAccount),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(deleteAccountServiceProvider)(
        account.id,
      );

      // Then
      expect(result.valueOrNull, same(account));
      verify(() => transactionsExist(account.id)).called(1);
      verify(() => deleteAccount(account.id)).called(1);
    });
  });
}
