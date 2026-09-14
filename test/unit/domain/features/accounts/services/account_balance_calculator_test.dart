@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('AccountBalanceCalculator', () {
    const calculator = AccountBalanceCalculator();
    final accountId = AccountId.fromString('account-123');
    final otherAccountId = AccountId.fromString('account-456');
    final denominationAssetId = AssetId.fromString('asset-chf');
    final otherAssetId = AssetId.fromString('asset-eur');
    final valuationAssetId = AssetId.fromString('asset-usd');

    LedgerEntry createEntry({
      AccountId? forAccountId,
      AssetId? accountAssetId,
      AssetId? transactionAssetId,
      required String accountAmount,
      String transactionAmount = '1',
      String valuationAmount = '1',
      bool incoming = true,
    }) {
      final createAssetAmount = incoming
          ? AssetAmount.incoming
          : AssetAmount.outgoing;

      return LedgerEntry(
        accountId: forAccountId ?? accountId,
        transactionAmount: createAssetAmount(
          assetId: transactionAssetId ?? otherAssetId,
          amount: Decimal.parse(transactionAmount),
        ),
        accountAmount: createAssetAmount(
          assetId: accountAssetId ?? denominationAssetId,
          amount: Decimal.parse(accountAmount),
        ),
        valuationAmount: createAssetAmount(
          assetId: valuationAssetId,
          amount: Decimal.parse(valuationAmount),
        ),
        role: LedgerEntryRole.primary,
      );
    }

    Decimal calculate(Iterable<LedgerEntry> ledgerEntries) {
      return calculator.calculate(
        accountId: accountId,
        denominationAssetId: denominationAssetId,
        ledgerEntries: ledgerEntries,
      );
    }

    test('returns zero when there are no entries', () {
      // When
      final balance = calculate(const []);

      // Then
      expect(balance, Decimal.zero);
    });

    test('adds an incoming account amount', () {
      // Given
      final entry = createEntry(accountAmount: '125.40');

      // When
      final balance = calculate([entry]);

      // Then
      expect(balance, Decimal.parse('125.40'));
    });

    test('subtracts an outgoing account amount', () {
      // Given
      final entry = createEntry(accountAmount: '42.75', incoming: false);

      // When
      final balance = calculate([entry]);

      // Then
      expect(balance, Decimal.parse('-42.75'));
    });

    test('nets mixed incoming and outgoing account amounts', () {
      // Given
      final entries = [
        createEntry(accountAmount: '100.25'),
        createEntry(accountAmount: '20.10', incoming: false),
        createEntry(accountAmount: '5.35'),
      ];

      // When
      final balance = calculate(entries);

      // Then
      expect(balance, Decimal.parse('85.50'));
    });

    test('returns zero when all entries belong to another account', () {
      // Given
      final entries = [
        createEntry(forAccountId: otherAccountId, accountAmount: '100'),
      ];

      // When
      final balance = calculate(entries);

      // Then
      expect(balance, Decimal.zero);
    });

    test('ignores unrelated entries alongside matching entries', () {
      // Given
      final entries = [
        createEntry(accountAmount: '25'),
        createEntry(forAccountId: otherAccountId, accountAmount: '100'),
        createEntry(accountAmount: '10', incoming: false),
      ];

      // When
      final balance = calculate(entries);

      // Then
      expect(balance, Decimal.parse('15'));
    });

    test('preserves decimal precision', () {
      // Given
      final entries = [
        createEntry(accountAmount: '0.1'),
        createEntry(accountAmount: '0.2'),
      ];

      // When
      final balance = calculate(entries);

      // Then
      expect(balance, Decimal.parse('0.3'));
    });

    test('uses account amount when transaction currency differs', () {
      // Given
      final entry = createEntry(
        accountAmount: '85.32',
        transactionAmount: '90',
        valuationAmount: '99.50',
      );

      // When
      final balance = calculate([entry]);

      // Then
      expect(balance, Decimal.parse('85.32'));
    });

    test('rejects a matching entry in another denomination', () {
      // Given
      final entry = createEntry(
        accountAssetId: otherAssetId,
        transactionAssetId: valuationAssetId,
        accountAmount: '10',
      );

      // When / Then
      expect(() => calculate([entry]), throwsArgumentError);
    });

    test('ignores another account with another denomination', () {
      // Given
      final entry = createEntry(
        forAccountId: otherAccountId,
        accountAssetId: otherAssetId,
        transactionAssetId: valuationAssetId,
        accountAmount: '10',
      );

      // When
      final balance = calculate([entry]);

      // Then
      expect(balance, Decimal.zero);
    });

    test('allows the balance to cross zero and become negative', () {
      // Given
      final entries = [
        createEntry(accountAmount: '50.25'),
        createEntry(accountAmount: '100.50', incoming: false),
      ];

      // When
      final balance = calculate(entries);

      // Then
      expect(balance, Decimal.parse('-50.25'));
    });
  });
}
