@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_custodian_summary_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../mocks/get_account_balance_service_mock.dart';
import '../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';
import '../../../mocks/get_custodian_by_id_use_case_mock.dart';

void main() {
  group('GetCustodianSummaryService', () {
    late MockGetCustodianByIdUseCase getCustodianById;
    late MockGetAccountsByCustodianIdUseCase getAccountsByCustodianId;
    late MockGetAccountBalanceService getAccountBalance;
    late GetCustodianSummaryService service;
    late Custodian custodian;

    setUp(() {
      getCustodianById = MockGetCustodianByIdUseCase();
      getAccountsByCustodianId = MockGetAccountsByCustodianIdUseCase();
      getAccountBalance = MockGetAccountBalanceService();

      service = GetCustodianSummaryService(
        getCustodianById: getCustodianById,
        getAccountsByCustodianId: getAccountsByCustodianId,
        getAccountBalance: getAccountBalance,
      );

      custodian = custodianFixture(id: 'custodian-summary');
    });

    setUpAll(() {
      registerFallbackValue(AccountId.fromString('fallback-account'));
      registerFallbackValue(CustodianId.fromString('fallback-custodian'));
    });

    Account createAccount({required String id, required String assetId}) {
      return accountFixture(
        id: id,
        custodianId: custodian.id.value,
        denominationAssetId: assetId,
      );
    }

    void stubCustodian() {
      when(
        () => getCustodianById(custodian.id),
      ).thenAnswer((_) async => Success<Custodian?>(custodian));
    }

    void stubAccounts(List<Account> accounts) {
      when(
        () => getAccountsByCustodianId(custodian.id),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));
    }

    test(
      'returns an empty summary when the custodian has no accounts',
      () async {
        // Given
        stubCustodian();
        stubAccounts(const []);

        // When
        final result = await service(custodian.id);

        // Then
        final summary = result.valueOrNull;

        expect(summary, isNotNull);
        expect(summary!.custodianId, custodian.id);
        expect(summary.accountCount, 0);
        expect(summary.balancesByAsset, isEmpty);

        verify(() => getCustodianById(custodian.id)).called(1);
        verify(() => getAccountsByCustodianId(custodian.id)).called(1);
        verifyNever(() => getAccountBalance(any()));
      },
    );

    test('returns one account balance under its denomination asset', () async {
      // Given
      final account = createAccount(id: 'account-chf', assetId: 'asset-chf');

      stubCustodian();
      stubAccounts([account]);

      when(
        () => getAccountBalance(account.id),
      ).thenAnswer((_) async => Success(Decimal.parse('125.40')));

      // When
      final result = await service(custodian.id);

      // Then
      final summary = result.valueOrNull!;

      expect(summary.accountCount, 1);
      expect(
        summary.balanceFor(account.denominationAssetId),
        Decimal.parse('125.40'),
      );
    });

    test('adds balances of accounts sharing a denomination asset', () async {
      // Given
      final first = createAccount(id: 'account-chf-1', assetId: 'asset-chf');
      final second = createAccount(id: 'account-chf-2', assetId: 'asset-chf');

      stubCustodian();
      stubAccounts([first, second]);

      when(
        () => getAccountBalance(first.id),
      ).thenAnswer((_) async => Success(Decimal.parse('100.25')));

      when(
        () => getAccountBalance(second.id),
      ).thenAnswer((_) async => Success(Decimal.parse('50.75')));

      // When
      final result = await service(custodian.id);

      // Then
      final summary = result.valueOrNull!;

      expect(summary.accountCount, 2);
      expect(summary.balancesByAsset.length, 1);
      expect(
        summary.balanceFor(first.denominationAssetId),
        Decimal.parse('151.00'),
      );
    });

    test('nets positive and negative balances in the same asset', () async {
      // Given
      final first = createAccount(id: 'account-positive', assetId: 'asset-chf');
      final second = createAccount(
        id: 'account-negative',
        assetId: 'asset-chf',
      );

      stubCustodian();
      stubAccounts([first, second]);

      when(
        () => getAccountBalance(first.id),
      ).thenAnswer((_) async => Success(Decimal.parse('100')));

      when(
        () => getAccountBalance(second.id),
      ).thenAnswer((_) async => Success(Decimal.parse('-25.50')));

      // When
      final result = await service(custodian.id);

      // Then
      final summary = result.valueOrNull!;

      expect(
        summary.balanceFor(first.denominationAssetId),
        Decimal.parse('74.50'),
      );
    });

    test('keeps balances in different denomination assets separate', () async {
      // Given
      final chfAccount = createAccount(id: 'account-chf', assetId: 'asset-chf');
      final eurAccount = createAccount(id: 'account-eur', assetId: 'asset-eur');

      stubCustodian();
      stubAccounts([chfAccount, eurAccount]);

      when(
        () => getAccountBalance(chfAccount.id),
      ).thenAnswer((_) async => Success(Decimal.parse('1000')));

      when(
        () => getAccountBalance(eurAccount.id),
      ).thenAnswer((_) async => Success(Decimal.parse('500')));

      // When
      final result = await service(custodian.id);

      // Then
      final summary = result.valueOrNull!;

      expect(summary.accountCount, 2);
      expect(summary.balancesByAsset.length, 2);
      expect(
        summary.balanceFor(chfAccount.denominationAssetId),
        Decimal.parse('1000'),
      );
      expect(
        summary.balanceFor(eurAccount.denominationAssetId),
        Decimal.parse('500'),
      );
    });

    test('preserves exact decimal arithmetic', () async {
      // Given
      final first = createAccount(
        id: 'account-decimal-1',
        assetId: 'asset-chf',
      );
      final second = createAccount(
        id: 'account-decimal-2',
        assetId: 'asset-chf',
      );

      stubCustodian();
      stubAccounts([first, second]);

      when(
        () => getAccountBalance(first.id),
      ).thenAnswer((_) async => Success(Decimal.parse('0.1')));

      when(
        () => getAccountBalance(second.id),
      ).thenAnswer((_) async => Success(Decimal.parse('0.2')));

      // When
      final result = await service(custodian.id);

      // Then
      expect(
        result.valueOrNull!.balanceFor(first.denominationAssetId),
        Decimal.parse('0.3'),
      );
    });

    test('keeps a zero aggregate balance in the asset summary', () async {
      // Given
      final first = createAccount(id: 'account-zero-1', assetId: 'asset-chf');
      final second = createAccount(id: 'account-zero-2', assetId: 'asset-chf');

      stubCustodian();
      stubAccounts([first, second]);

      when(
        () => getAccountBalance(first.id),
      ).thenAnswer((_) async => Success(Decimal.parse('50')));

      when(
        () => getAccountBalance(second.id),
      ).thenAnswer((_) async => Success(Decimal.parse('-50')));

      // When
      final result = await service(custodian.id);

      // Then
      final summary = result.valueOrNull!;

      expect(summary.balancesByAsset.length, 1);
      expect(summary.balanceFor(first.denominationAssetId), Decimal.zero);
    });

    test('returns zero from balanceFor for an absent asset', () async {
      // Given
      final account = createAccount(id: 'account-chf', assetId: 'asset-chf');
      final absentAssetId = AssetId.fromString('asset-eur');

      stubCustodian();
      stubAccounts([account]);

      when(
        () => getAccountBalance(account.id),
      ).thenAnswer((_) async => Success(Decimal.parse('100')));

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.valueOrNull!.balanceFor(absentAssetId), Decimal.zero);
    });

    test(
      'returns custodian-not-found when the custodian does not exist',
      () async {
        // Given
        when(
          () => getCustodianById(custodian.id),
        ).thenAnswer((_) async => const Success<Custodian?>(null));

        // When
        final result = await service(custodian.id);

        // Then
        expect(result.failureOrNull, isA<CustodianNotFoundFailure>());

        verify(() => getCustodianById(custodian.id)).called(1);
        verifyNever(() => getAccountsByCustodianId(any()));
        verifyNever(() => getAccountBalance(any()));
      },
    );

    test('propagates custodian lookup failures unchanged', () async {
      // Given
      const failure = CustodianNotFoundFailure(
        message: 'custodian lookup failed',
      );

      when(
        () => getCustodianById(custodian.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => getAccountsByCustodianId(any()));
      verifyNever(() => getAccountBalance(any()));
    });

    test('propagates account lookup failures unchanged', () async {
      // Given
      const failure = AccountNotFoundFailure(message: 'account lookup failed');

      stubCustodian();

      when(
        () => getAccountsByCustodianId(custodian.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => getAccountBalance(any()));
    });

    test('propagates an account balance failure unchanged', () async {
      // Given
      final first = createAccount(id: 'account-first', assetId: 'asset-chf');

      const failure = AccountNotFoundFailure(
        message: 'balance account missing',
      );

      stubCustodian();
      stubAccounts([first]);

      when(() => getAccountBalance(first.id)).thenAnswer((_) async => failure);

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('stops calculating after the first account balance failure', () async {
      // Given
      final first = createAccount(id: 'account-first', assetId: 'asset-chf');
      final second = createAccount(id: 'account-second', assetId: 'asset-chf');
      final third = createAccount(id: 'account-third', assetId: 'asset-chf');

      const failure = AccountNotFoundFailure(message: 'second balance failed');

      stubCustodian();
      stubAccounts([first, second, third]);

      when(
        () => getAccountBalance(first.id),
      ).thenAnswer((_) async => Success(Decimal.parse('100')));

      when(() => getAccountBalance(second.id)).thenAnswer((_) async => failure);

      // When
      final result = await service(custodian.id);

      // Then
      expect(result.failureOrNull, same(failure));

      verify(() => getAccountBalance(first.id)).called(1);
      verify(() => getAccountBalance(second.id)).called(1);
      verifyNever(() => getAccountBalance(third.id));
    });

    test('requests each account balance exactly once', () async {
      // Given
      final first = createAccount(id: 'account-first', assetId: 'asset-chf');
      final second = createAccount(id: 'account-second', assetId: 'asset-eur');

      stubCustodian();
      stubAccounts([first, second]);

      when(
        () => getAccountBalance(first.id),
      ).thenAnswer((_) async => Success(Decimal.parse('10')));

      when(
        () => getAccountBalance(second.id),
      ).thenAnswer((_) async => Success(Decimal.parse('20')));

      // When
      await service(custodian.id);

      // Then
      verify(() => getAccountBalance(first.id)).called(1);
      verify(() => getAccountBalance(second.id)).called(1);
    });
  });
}
