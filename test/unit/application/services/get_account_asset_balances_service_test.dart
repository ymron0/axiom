@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_account_asset_balances_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:axiom/src/features/accounts/domain/services/account_asset_balance_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../mocks/account_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  late MockAccountRepository accountRepository;
  late MockTransactionRepository transactionRepository;
  late GetAccountAssetBalancesService service;

  final now = DateTime.utc(2026, 9, 20, 12);
  final usd = AssetId.fromString('asset-usd');
  final btc = AssetId.fromString('asset-btc');

  setUp(() {
    accountRepository = MockAccountRepository();
    transactionRepository = MockTransactionRepository();

    service = GetAccountAssetBalancesService(
      getAccountById: GetAccountByIdUseCase(accountRepository),
      getTransactionsByAccountId: GetTransactionsByAccountIdUseCase(
        transactionRepository,
      ),
      calculator: const AccountAssetBalanceCalculator(),
      clock: FixedClock(now),
    );
  });

  test('returns current actual asset balances', () async {
    final account = accountFixture(id: 'account-main');

    final transactions = [
      _transaction(
        id: 'usd-income',
        accountId: account.id,
        assetId: usd,
        amount: '100',
        incoming: true,
        effectiveAt: DateTime.utc(2026, 9, 20, 8),
      ),
      _transaction(
        id: 'btc-income',
        accountId: account.id,
        assetId: btc,
        amount: '2',
        incoming: true,
        effectiveAt: DateTime.utc(2026, 9, 20, 9),
      ),
      _transaction(
        id: 'usd-expense',
        accountId: account.id,
        assetId: usd,
        amount: '25',
        incoming: false,
        effectiveAt: DateTime.utc(2026, 9, 20, 10),
      ),
    ];

    when(
      () => accountRepository.getById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(
      () => transactionRepository.getTransactionsByAccountId(account.id),
    ).thenAnswer((_) async => Success<List<Transaction>>(transactions));

    final result = await service(account.id);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, hasLength(2));

    final btcBalance = result.valueOrNull!.singleWhere(
      (amount) => amount.assetId == btc,
    );
    final usdBalance = result.valueOrNull!.singleWhere(
      (amount) => amount.assetId == usd,
    );

    expect(btcBalance.amount, Decimal.parse('2'));
    expect(btcBalance.isIncoming, isTrue);

    expect(usdBalance.amount, Decimal.parse('75'));
    expect(usdBalance.isIncoming, isTrue);
  });

  test('ignores planned transactions', () async {
    final account = accountFixture(id: 'account-main');

    final planned = _transaction(
      id: 'planned',
      accountId: account.id,
      assetId: usd,
      amount: '100',
      incoming: true,
      effectiveAt: DateTime.utc(2026, 9, 20, 8),
      state: TransactionState.planned,
    );

    when(
      () => accountRepository.getById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(
      () => transactionRepository.getTransactionsByAccountId(account.id),
    ).thenAnswer((_) async => Success<List<Transaction>>([planned]));

    final result = await service(account.id);

    expect(result.valueOrNull, isEmpty);
  });

  test('ignores future actual transactions', () async {
    final account = accountFixture(id: 'account-main');

    final future = _transaction(
      id: 'future',
      accountId: account.id,
      assetId: usd,
      amount: '100',
      incoming: true,
      effectiveAt: DateTime.utc(2026, 9, 20, 13),
    );

    when(
      () => accountRepository.getById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(
      () => transactionRepository.getTransactionsByAccountId(account.id),
    ).thenAnswer((_) async => Success<List<Transaction>>([future]));

    final result = await service(account.id);

    expect(result.valueOrNull, isEmpty);
  });

  test('returns account-not-found when account does not exist', () async {
    final id = AccountId.fromString('missing-account');

    when(
      () => accountRepository.getById(id),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(id);

    expect(result.failureOrNull, isA<AccountNotFoundFailure>());

    verifyNever(() => transactionRepository.getTransactionsByAccountId(id));
  });

  test('propagates account repository failure', () async {
    final id = AccountId.fromString('failed-account');

    const failure = AccountRepositoryFailure(message: 'account lookup failed');

    when(() => accountRepository.getById(id)).thenAnswer((_) async => failure);

    final result = await service(id);

    expect(result.failureOrNull, same(failure));
  });

  test('propagates transaction repository failure', () async {
    final account = accountFixture(id: 'account-main');

    const failure = TransactionRepositoryFailure(
      message: 'transaction lookup failed',
    );

    when(
      () => accountRepository.getById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(
      () => transactionRepository.getTransactionsByAccountId(account.id),
    ).thenAnswer((_) async => failure);

    final result = await service(account.id);

    expect(result.failureOrNull, same(failure));
  });
}

Transaction _transaction({
  required String id,
  required AccountId accountId,
  required AssetId assetId,
  required String amount,
  required bool incoming,
  required DateTime effectiveAt,
  TransactionState state = TransactionState.actual,
}) {
  final assetAmount = incoming
      ? AssetAmount.incoming(assetId: assetId, amount: Decimal.parse(amount))
      : AssetAmount.outgoing(assetId: assetId, amount: Decimal.parse(amount));

  final timestamp = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString(id),
    kind: incoming ? TransactionKind.income : TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    state: state,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: accountId,
        transactionAmount: assetAmount,
        accountAmount: assetAmount,
        valuationAmount: assetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
