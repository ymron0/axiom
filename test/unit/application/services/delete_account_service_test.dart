@Tags(['application'])
library;

import 'package:axiom/src/application/services/delete_account_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_in_use_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../mocks/delete_account_use_case_mock.dart';
import '../../../mocks/transactions_exist_by_account_id_use_case_mock.dart';

void main() {
  group('DeleteAccountService', () {
    late MockTransactionsExistByAccountIdUseCase transactionsExist;
    late MockDeleteAccountUseCase deleteAccount;
    late DeleteAccountService service;

    setUp(() {
      transactionsExist = MockTransactionsExistByAccountIdUseCase();
      deleteAccount = MockDeleteAccountUseCase();
      service = DeleteAccountService(
        transactionsExist: transactionsExist,
        deleteAccount: deleteAccount,
      );
    });

    test('deletes an account with no associated transactions', () async {
      // Given
      final account = accountFixture(
        id: 'unused-account',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => transactionsExist(account.id),
      ).thenAnswer((_) async => const Success(false));
      when(
        () => deleteAccount(account.id),
      ).thenAnswer((_) async => Success<Account>(account));

      // When
      final result = await service(account.id);

      // Then
      expect(result.valueOrNull, same(account));
      verify(() => transactionsExist(account.id)).called(1);
      verify(() => deleteAccount(account.id)).called(1);
    });

    test('does not delete an account with associated transactions', () async {
      // Given
      final account = accountFixture(id: 'used-account');
      when(
        () => transactionsExist(account.id),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await service(account.id);

      // Then
      expect(result.failureOrNull, isA<AccountInUseFailure>());
      expect(result.failureOrNull?.message, contains(account.id.value));
      verify(() => transactionsExist(account.id)).called(1);
      verifyNever(() => deleteAccount(account.id));
    });

    test('propagates transaction lookup failures without deleting', () async {
      // Given
      final account = accountFixture(id: 'lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(
        () => transactionsExist(account.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(account.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => deleteAccount(account.id));
    });

    test('propagates account deletion failures', () async {
      // Given
      final account = accountFixture(id: 'missing-account');
      const failure = AccountNotFoundFailure(message: 'missing');
      when(
        () => transactionsExist(account.id),
      ).thenAnswer((_) async => const Success(false));
      when(() => deleteAccount(account.id)).thenAnswer((_) async => failure);

      // When
      final result = await service(account.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => deleteAccount(account.id)).called(1);
    });
  });
}
