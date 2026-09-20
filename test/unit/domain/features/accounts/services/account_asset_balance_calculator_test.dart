@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/accounts/domain/services/account_asset_balance_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  const calculator = AccountAssetBalanceCalculator();

  final accountId = AccountId.fromString('account-main');
  final otherAccountId = AccountId.fromString('account-other');
  final btc = AssetId.fromString('asset-btc');
  final chf = AssetId.fromString('asset-chf');
  final usd = AssetId.fromString('asset-usd');

  test('aggregates multiple positions independently by asset', () {
    final result = calculator.calculate(
      accountId: accountId,
      ledgerEntries: [
        _entry(
          accountId: accountId,
          assetId: usd,
          amount: '100',
          incoming: true,
        ),
        _entry(accountId: accountId, assetId: btc, amount: '2', incoming: true),
        _entry(
          accountId: accountId,
          assetId: usd,
          amount: '25',
          incoming: false,
        ),
      ],
    );

    expect(result, hasLength(2));

    expect(result[0].assetId, btc);
    expect(result[0].amount, Decimal.parse('2'));
    expect(result[0].isIncoming, isTrue);

    expect(result[1].assetId, usd);
    expect(result[1].amount, Decimal.parse('75'));
    expect(result[1].isIncoming, isTrue);
  });

  test('represents a net-negative position as outgoing', () {
    final result = calculator.calculate(
      accountId: accountId,
      ledgerEntries: [
        _entry(
          accountId: accountId,
          assetId: chf,
          amount: '20',
          incoming: true,
        ),
        _entry(
          accountId: accountId,
          assetId: chf,
          amount: '50',
          incoming: false,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.assetId, chf);
    expect(result.single.amount, Decimal.parse('30'));
    expect(result.single.isOutgoing, isTrue);
  });

  test('omits a position whose net amount is zero', () {
    final result = calculator.calculate(
      accountId: accountId,
      ledgerEntries: [
        _entry(
          accountId: accountId,
          assetId: usd,
          amount: '50',
          incoming: true,
        ),
        _entry(
          accountId: accountId,
          assetId: usd,
          amount: '50',
          incoming: false,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('ignores ledger entries belonging to another account', () {
    final result = calculator.calculate(
      accountId: accountId,
      ledgerEntries: [
        _entry(
          accountId: otherAccountId,
          assetId: usd,
          amount: '100',
          incoming: true,
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('returns an immutable collection', () {
    final result = calculator.calculate(
      accountId: accountId,
      ledgerEntries: [
        _entry(
          accountId: accountId,
          assetId: usd,
          amount: '10',
          incoming: true,
        ),
      ],
    );

    expect(
      () => result.add(AssetAmount.incoming(assetId: chf, amount: Decimal.one)),
      throwsUnsupportedError,
    );
  });

  test('rejects an unknown transaction amount', () {
    final unknown = AssetAmount.incoming(
      assetId: usd,
      amount: Decimal.fromInt(-1),
    );

    final entry = LedgerEntry(
      accountId: accountId,
      transactionAmount: unknown,
      accountAmount: unknown,
      valuationAmount: unknown,
      role: LedgerEntryRole.primary,
    );

    expect(
      () => calculator.calculate(accountId: accountId, ledgerEntries: [entry]),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'name',
          'ledgerEntries',
        ),
      ),
    );
  });
}

LedgerEntry _entry({
  required AccountId accountId,
  required AssetId assetId,
  required String amount,
  required bool incoming,
}) {
  final assetAmount = incoming
      ? AssetAmount.incoming(assetId: assetId, amount: Decimal.parse(amount))
      : AssetAmount.outgoing(assetId: assetId, amount: Decimal.parse(amount));

  return LedgerEntry(
    accountId: accountId,
    transactionAmount: assetAmount,
    accountAmount: assetAmount,
    valuationAmount: assetAmount,
    role: LedgerEntryRole.primary,
  );
}
