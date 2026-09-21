@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_payment_asset_failure.dart';
import 'package:axiom/src/application/failures/invalid_trade_asset_failure.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';

void main() {
  late MockAssetRepository assetRepository;
  late MockSettingsRepository settingsRepository;
  late ValidateTransactionAssetSemanticsService service;

  final valuationId = AssetId.fromString('valuation-chf');
  final cashId = AssetId.fromString('cash-eur');
  final stockId = AssetId.fromString('stock-nvda');
  final cryptoId = AssetId.fromString('crypto-btc');

  setUp(() {
    assetRepository = MockAssetRepository();
    settingsRepository = MockSettingsRepository();

    service = ValidateTransactionAssetSemanticsService(
      getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
      getValuationCurrency: GetValuationCurrencyService(
        getSettings: GetSettingsUseCase(settingsRepository),
        getAssetById: GetAssetByIdUseCase(assetRepository),
      ),
    );

    when(() => settingsRepository.get()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: valuationId)),
    );

    when(
      () => assetRepository.getById(valuationId),
    ).thenAnswer((_) async => Success(_currency(valuationId, code: 'CHF')));
  });

  void stubAssets(List<Asset> assets) {
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Asset, AssetId>(found: assets, missing: const []),
      ),
    );
  }

  test('accepts an expense with a payment-enabled primary asset', () async {
    final transaction = _transaction(
      kind: TransactionKind.expense,
      ledgerEntries: [
        _entry(
          account: 'cash',
          transactionAmount: _outgoing(cashId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([_currency(cashId), _currency(valuationId, code: 'CHF')]);

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('allows an expense fee to use a non-payment asset', () async {
    final transaction = _transaction(
      kind: TransactionKind.expense,
      ledgerEntries: [
        _entry(
          account: 'cash',
          transactionAmount: _outgoing(cashId),
          valuationId: valuationId,
        ),
        _entry(
          account: 'stock-fee',
          transactionAmount: _outgoing(stockId),
          valuationId: valuationId,
          role: LedgerEntryRole.fee,
        ),
      ],
    );

    stubAssets([
      _currency(cashId),
      _stock(stockId),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('rejects a disabled primary payment asset', () async {
    final transaction = _transaction(
      kind: TransactionKind.expense,
      ledgerEntries: [
        _entry(
          account: 'crypto',
          transactionAmount: _outgoing(cryptoId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([
      _crypto(cryptoId, paymentEnabled: false),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.failureOrNull, isA<InvalidPaymentAssetFailure>());
  });

  test('accepts buying a non-cash asset with currency', () async {
    final transaction = _transaction(
      kind: TransactionKind.buy,
      ledgerEntries: [
        _entry(
          account: 'cash',
          transactionAmount: _outgoing(cashId),
          valuationId: valuationId,
        ),
        _entry(
          account: 'shares',
          transactionAmount: _incoming(stockId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([
      _currency(cashId),
      _stock(stockId),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('accepts selling a non-cash asset for currency', () async {
    final transaction = _transaction(
      kind: TransactionKind.sell,
      ledgerEntries: [
        _entry(
          account: 'shares',
          transactionAmount: _outgoing(stockId),
          valuationId: valuationId,
        ),
        _entry(
          account: 'cash',
          transactionAmount: _incoming(cashId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([
      _currency(cashId),
      _stock(stockId),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('rejects buying a currency as the traded asset', () async {
    final secondCurrencyId = AssetId.fromString('cash-usd');

    final transaction = _transaction(
      kind: TransactionKind.buy,
      ledgerEntries: [
        _entry(
          account: 'cash-eur',
          transactionAmount: _outgoing(cashId),
          valuationId: valuationId,
        ),
        _entry(
          account: 'cash-usd',
          transactionAmount: _incoming(secondCurrencyId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([
      _currency(cashId),
      _currency(secondCurrencyId, code: 'USD'),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.failureOrNull, isA<InvalidTradeAssetFailure>());
  });

  test('rejects a trade using a disabled settlement asset', () async {
    final transaction = _transaction(
      kind: TransactionKind.buy,
      ledgerEntries: [
        _entry(
          account: 'crypto',
          transactionAmount: _outgoing(cryptoId),
          valuationId: valuationId,
        ),
        _entry(
          account: 'shares',
          transactionAmount: _incoming(stockId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([
      _crypto(cryptoId, paymentEnabled: false),
      _stock(stockId),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.failureOrNull, isA<InvalidPaymentAssetFailure>());
  });

  test('accepts a dividend received as a non-cash asset', () async {
    final transaction = _transaction(
      kind: TransactionKind.dividend,
      ledgerEntries: [
        _entry(
          account: 'shares',
          transactionAmount: _incoming(stockId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([_stock(stockId), _currency(valuationId, code: 'CHF')]);

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('accepts a reward received as disabled-for-payment crypto', () async {
    final transaction = _transaction(
      kind: TransactionKind.reward,
      ledgerEntries: [
        _entry(
          account: 'crypto',
          transactionAmount: _incoming(cryptoId),
          valuationId: valuationId,
        ),
      ],
    );

    stubAssets([
      _crypto(cryptoId, paymentEnabled: false),
      _currency(valuationId, code: 'CHF'),
    ]);

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('rejects a missing referenced asset', () async {
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Asset, AssetId>(found: const [], missing: [cashId]),
      ),
    );

    final result = await service(
      _transaction(
        kind: TransactionKind.expense,
        ledgerEntries: [
          _entry(
            account: 'cash',
            transactionAmount: _outgoing(cashId),
            valuationId: valuationId,
          ),
        ],
      ),
    );

    expect(result.failureOrNull?.message, contains(cashId.value));
    verifyNever(() => settingsRepository.get());
  });

  test('propagates asset lookup failures', () async {
    const failure = AssetRepositoryFailure(message: 'batch lookup failed');

    when(
      () => assetRepository.getByIds(any()),
    ).thenAnswer((_) async => failure);

    final result = await service(
      _transaction(
        kind: TransactionKind.expense,
        ledgerEntries: [
          _entry(
            account: 'cash',
            transactionAmount: _outgoing(cashId),
            valuationId: valuationId,
          ),
        ],
      ),
    );

    expect(result.failureOrNull, same(failure));
  });

  test('rejects a valuation amount in the wrong currency', () async {
    final wrongValuationId = AssetId.fromString('valuation-usd');

    final transaction = _transaction(
      kind: TransactionKind.expense,
      ledgerEntries: [
        _entry(
          account: 'cash',
          transactionAmount: _outgoing(cashId),
          valuationId: wrongValuationId,
        ),
      ],
    );

    stubAssets([_currency(cashId), _currency(wrongValuationId, code: 'USD')]);

    final result = await service(transaction);

    expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
    expect(result.failureOrNull?.message, contains(valuationId.value));
  });

}

Transaction _transaction({
  required TransactionKind kind,
  required List<LedgerEntry> ledgerEntries,
}) {
  return Transaction(
    id: TransactionId.fromString('transaction-semantics'),
    kind: kind,
    merchantId: MerchantId.self,
    effectiveAt: DateTime.utc(2026),
    description: 'Semantics test',
    note: null,
    state: TransactionState.actual,
    deletedAt: null,
    tagIds: const [],
    splits: const [],
    ledgerEntries: ledgerEntries,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    entityVersion: 1,
  );
}

LedgerEntry _entry({
  required String account,
  required AssetAmount transactionAmount,
  required AssetId valuationId,
  LedgerEntryRole role = LedgerEntryRole.primary,
}) {
  final valuationAmount = AssetAmount(
    assetId: valuationId,
    amount: transactionAmount.amount,
    direction: transactionAmount.direction,
  );

  return LedgerEntry(
    accountId: AccountId.fromString(account),
    transactionAmount: transactionAmount,
    accountAmount: transactionAmount,
    valuationAmount: valuationAmount,
    role: role,
  );
}

AssetAmount _incoming(AssetId assetId) {
  return AssetAmount.incoming(assetId: assetId, amount: Decimal.fromInt(10));
}

AssetAmount _outgoing(AssetId assetId) {
  return AssetAmount.outgoing(assetId: assetId, amount: Decimal.fromInt(10));
}

Currency _currency(AssetId id, {String code = 'EUR'}) {
  return Currency(
    id: id,
    entityVersion: 1,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    name: id.value,
    code: AssetCode(code),
    decimalPlaces: 2,
  );
}

StockAsset _stock(AssetId id) {
  return StockAsset(
    id: id,
    entityVersion: 1,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    name: 'Stock',
    code: AssetCode('NVDA'),
    decimalPlaces: 6,
  );
}

CryptoAsset _crypto(AssetId id, {required bool paymentEnabled}) {
  return CryptoAsset(
    id: id,
    entityVersion: 1,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    name: 'Bitcoin',
    code: AssetCode('BTC'),
    decimalPlaces: 8,
    paymentEnabled: paymentEnabled,
  );
}
