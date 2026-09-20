@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_payment_asset_failure.dart';
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
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
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
  final paymentId = AssetId.fromString('payment-eur');

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
    ).thenAnswer((_) async => Success(_currency(valuationId)));
  });

  test('accepts an expense with a payment-enabled asset', () async {
    final transaction = _transaction();
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async =>
          Success(_lookup([_currency(paymentId), _currency(valuationId)])),
    );

    final result = await service(transaction);

    expect(result.isSuccess, isTrue);
  });

  test('rejects a missing referenced asset', () async {
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Asset, AssetId>(found: const [], missing: [paymentId]),
      ),
    );

    final result = await service(_transaction());

    expect(result.failureOrNull?.message, contains(paymentId.value));
    verifyNever(() => settingsRepository.get());
  });

  test('propagates asset lookup failures', () async {
    const failure = AssetRepositoryFailure(message: 'batch lookup failed');
    when(
      () => assetRepository.getByIds(any()),
    ).thenAnswer((_) async => failure);

    final result = await service(_transaction());

    expect(result.failureOrNull, same(failure));
  });

  test('rejects a valuation amount in the wrong currency', () async {
    final wrongValuationId = AssetId.fromString('valuation-usd');
    final transaction = _transaction(valuationAssetId: wrongValuationId);
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async =>
          Success(_lookup([_currency(paymentId), _currency(wrongValuationId)])),
    );

    final result = await service(transaction);

    expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
    expect(result.failureOrNull?.message, contains(valuationId.value));
  });

  test('rejects a payment asset that is disabled', () async {
    final crypto = CryptoAsset(
      id: paymentId,
      entityVersion: 1,
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
    );
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async => Success(_lookup([crypto, _currency(valuationId)])),
    );

    final result = await service(_transaction());

    expect(result.failureOrNull, isA<InvalidPaymentAssetFailure>());
    expect(result.failureOrNull?.message, contains('BTC'));
  });

  test('does not require payment eligibility for transfers', () async {
    final crypto = CryptoAsset(
      id: paymentId,
      entityVersion: 1,
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
    );
    when(() => assetRepository.getByIds(any())).thenAnswer(
      (_) async => Success(_lookup([crypto, _currency(valuationId)])),
    );

    final result = await service(_transaction(kind: TransactionKind.transfer));

    expect(result.isSuccess, isTrue);
  });
}

BatchLookup<Asset, AssetId> _lookup(List<Asset> found) {
  return BatchLookup<Asset, AssetId>(found: found, missing: const []);
}

Currency _currency(AssetId id) {
  return Currency(
    id: id,
    entityVersion: 1,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    name: id.value,
    code: AssetCode('EUR'),
    decimalPlaces: 2,
  );
}

AssetAmount _amount(AssetId assetId) {
  return AssetAmount.outgoing(assetId: assetId, amount: Decimal.fromInt(10));
}

Transaction _transaction({
  TransactionKind kind = TransactionKind.expense,
  AssetId? valuationAssetId,
  List<TransactionSplit> splits = const [],
}) {
  final valuation = valuationAssetId ?? AssetId.fromString('valuation-chf');
  final payment = _amount(AssetId.fromString('payment-eur'));
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
    splits: splits,
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account'),
        transactionAmount: payment,
        accountAmount: payment,
        valuationAmount: _amount(valuation),
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    entityVersion: 1,
  );
}
