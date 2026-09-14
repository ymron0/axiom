@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../mocks/get_ledger_entries_by_account_id_use_case_mock.dart';

void main() {
  group('GetAccountBalanceService', () {
    late MockGetAccountByIdUseCase getAccountById;
    late MockGetLedgerEntriesByAccountIdUseCase getLedgerEntriesByAccountId;
    late GetAccountBalanceService service;
    late Account account;

    setUp(() {
      getAccountById = MockGetAccountByIdUseCase();
      getLedgerEntriesByAccountId = MockGetLedgerEntriesByAccountIdUseCase();
      service = GetAccountBalanceService(
        getAccountById: getAccountById,
        getLedgerEntriesByAccountId: getLedgerEntriesByAccountId,
        calculator: const AccountBalanceCalculator(),
      );
      account = accountFixture(id: 'balance-account');
    });

    LedgerEntry createEntry({required String amount, bool incoming = true}) {
      final accountAmount = incoming
          ? AssetAmount.incoming(
              assetId: account.denominationAssetId,
              amount: Decimal.parse(amount),
            )
          : AssetAmount.outgoing(
              assetId: account.denominationAssetId,
              amount: Decimal.parse(amount),
            );

      return LedgerEntry(
        accountId: account.id,
        transactionAmount: accountAmount,
        accountAmount: accountAmount,
        valuationAmount: accountAmount,
        role: LedgerEntryRole.primary,
      );
    }

    test('returns the balance derived from matching ledger entries', () async {
      // Given
      final entries = [
        createEntry(amount: '100.25'),
        createEntry(amount: '40.10', incoming: false),
      ];
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success<Account?>(account));
      when(
        () => getLedgerEntriesByAccountId(account.id),
      ).thenAnswer((_) async => Success<List<LedgerEntry>>(entries));

      // When
      final result = await service(account.id);

      // Then
      expect(result.valueOrNull, Decimal.parse('60.15'));
      verify(() => getAccountById(account.id)).called(1);
      verify(() => getLedgerEntriesByAccountId(account.id)).called(1);
    });

    test('returns zero when the account has no ledger entries', () async {
      // Given
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success<Account?>(account));
      when(
        () => getLedgerEntriesByAccountId(account.id),
      ).thenAnswer((_) async => const Success<List<LedgerEntry>>([]));

      // When
      final result = await service(account.id);

      // Then
      expect(result.valueOrNull, Decimal.zero);
    });

    test(
      'returns an account-not-found failure when the account is absent',
      () async {
        // Given
        when(
          () => getAccountById(account.id),
        ).thenAnswer((_) async => const Success<Account?>(null));

        // When
        final result = await service(account.id);

        // Then
        expect(result.failureOrNull, isA<AccountNotFoundFailure>());
        verifyNever(() => getLedgerEntriesByAccountId(account.id));
      },
    );

    test('propagates account lookup failures', () async {
      // Given
      const failure = AccountNotFoundFailure(message: 'account read failed');
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(account.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => getLedgerEntriesByAccountId(account.id));
    });

    test('propagates ledger-entry lookup failures', () async {
      // Given
      const failure = TransactionNotFoundFailure(
        message: 'transaction read failed',
      );
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success<Account?>(account));
      when(
        () => getLedgerEntriesByAccountId(account.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(account.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
