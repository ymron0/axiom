import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('LedgerEntry', () {
    final accountId = AccountId.fromString('account-123');
    final transactionAssetId = AssetId.fromString('transaction-asset');
    final accountAssetId = AssetId.fromString('account-asset');
    final valuationAssetId = AssetId.fromString('valuation-asset');

    test('accepts incoming amounts in three different assets', () {
      // Given
      final transactionAmount = AssetAmount.incoming(
        assetId: transactionAssetId,
        amount: Decimal.parse('100.00'),
      );
      final accountAmount = AssetAmount.incoming(
        assetId: accountAssetId,
        amount: Decimal.parse('85.20'),
      );
      final valuationAmount = AssetAmount.incoming(
        assetId: valuationAssetId,
        amount: Decimal.parse('79.40'),
      );

      // When
      final entry = LedgerEntry(
        accountId: accountId,
        transactionAmount: transactionAmount,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
        role: LedgerEntryRole.primary,
      );

      // Then
      expect(entry.accountId, same(accountId));
      expect(entry.transactionAmount, same(transactionAmount));
      expect(entry.accountAmount, same(accountAmount));
      expect(entry.valuationAmount, same(valuationAmount));
      expect(entry.role, LedgerEntryRole.primary);
    });

    test('accepts matching outgoing amounts in different assets', () {
      // When
      final entry = LedgerEntry(
        accountId: accountId,
        transactionAmount: AssetAmount.outgoing(
          assetId: transactionAssetId,
          amount: Decimal.parse('10'),
        ),
        accountAmount: AssetAmount.outgoing(
          assetId: accountAssetId,
          amount: Decimal.parse('8.50'),
        ),
        valuationAmount: AssetAmount.outgoing(
          assetId: valuationAssetId,
          amount: Decimal.parse('9.25'),
        ),
        role: LedgerEntryRole.fee,
      );

      // Then
      expect(entry.role, LedgerEntryRole.fee);
    });

    test('accepts equal quantities when amounts use the same asset', () {
      // Given
      final amount = Decimal.parse('12.50');

      // When
      final entry = LedgerEntry(
        accountId: accountId,
        transactionAmount: AssetAmount.outgoing(
          assetId: transactionAssetId,
          amount: amount,
        ),
        accountAmount: AssetAmount.outgoing(
          assetId: transactionAssetId,
          amount: amount,
        ),
        valuationAmount: AssetAmount.outgoing(
          assetId: transactionAssetId,
          amount: amount,
        ),
        role: LedgerEntryRole.primary,
      );

      // Then
      expect(entry.transactionAmount.amount, amount);
      expect(entry.accountAmount.amount, amount);
      expect(entry.valuationAmount.amount, amount);
    });

    test(
      'accepts equal unknown quantities when amounts use the same asset',
      () {
        // When
        final entry = LedgerEntry(
          accountId: accountId,
          transactionAmount: AssetAmount.incoming(
            assetId: transactionAssetId,
            amount: Decimal.fromInt(-1),
          ),
          accountAmount: AssetAmount.incoming(
            assetId: transactionAssetId,
            amount: Decimal.fromInt(-1),
          ),
          valuationAmount: AssetAmount.incoming(
            assetId: transactionAssetId,
            amount: Decimal.fromInt(-1),
          ),
          role: LedgerEntryRole.primary,
        );

        // Then
        expect(entry.transactionAmount.isUnknownAmount, isTrue);
        expect(entry.accountAmount.isUnknownAmount, isTrue);
        expect(entry.valuationAmount.isUnknownAmount, isTrue);
      },
    );

    test('rejects amounts with different directions', () {
      // When / Then
      expect(
        () => LedgerEntry(
          accountId: accountId,
          transactionAmount: AssetAmount.incoming(
            assetId: transactionAssetId,
            amount: Decimal.one,
          ),
          accountAmount: AssetAmount.incoming(
            assetId: accountAssetId,
            amount: Decimal.one,
          ),
          valuationAmount: AssetAmount.outgoing(
            assetId: valuationAssetId,
            amount: Decimal.one,
          ),
          role: LedgerEntryRole.primary,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Valuation amount must have the same direction as the transaction '
                'amount.',
          ),
        ),
      );
    });

    test('rejects an account amount with a different direction', () {
      // When / Then
      expect(
        () => LedgerEntry(
          accountId: accountId,
          transactionAmount: AssetAmount.incoming(
            assetId: transactionAssetId,
            amount: Decimal.one,
          ),
          accountAmount: AssetAmount.outgoing(
            assetId: accountAssetId,
            amount: Decimal.one,
          ),
          valuationAmount: AssetAmount.incoming(
            assetId: valuationAssetId,
            amount: Decimal.one,
          ),
          role: LedgerEntryRole.primary,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Account amount must have the same direction as the transaction '
                'amount.',
          ),
        ),
      );
    });

    test('rejects outgoing amounts with a different account direction', () {
      // When / Then
      expect(
        () => LedgerEntry(
          accountId: accountId,
          transactionAmount: AssetAmount.outgoing(
            assetId: transactionAssetId,
            amount: Decimal.one,
          ),
          accountAmount: AssetAmount.incoming(
            assetId: accountAssetId,
            amount: Decimal.one,
          ),
          valuationAmount: AssetAmount.outgoing(
            assetId: valuationAssetId,
            amount: Decimal.one,
          ),
          role: LedgerEntryRole.primary,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Account amount must have the same direction as the transaction '
                'amount.',
          ),
        ),
      );
    });

    test('rejects outgoing amounts with a different valuation direction', () {
      // When / Then
      expect(
        () => LedgerEntry(
          accountId: accountId,
          transactionAmount: AssetAmount.outgoing(
            assetId: transactionAssetId,
            amount: Decimal.one,
          ),
          accountAmount: AssetAmount.outgoing(
            assetId: accountAssetId,
            amount: Decimal.one,
          ),
          valuationAmount: AssetAmount.incoming(
            assetId: valuationAssetId,
            amount: Decimal.one,
          ),
          role: LedgerEntryRole.primary,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Valuation amount must have the same direction as the transaction '
                'amount.',
          ),
        ),
      );
    });

    test(
      'rejects different transaction and valuation quantities in one asset',
      () {
        // When / Then
        expect(
          () => LedgerEntry(
            accountId: accountId,
            transactionAmount: AssetAmount.outgoing(
              assetId: transactionAssetId,
              amount: Decimal.parse('10'),
            ),
            accountAmount: AssetAmount.outgoing(
              assetId: accountAssetId,
              amount: Decimal.parse('8.50'),
            ),
            valuationAmount: AssetAmount.outgoing(
              assetId: transactionAssetId,
              amount: Decimal.parse('9.99'),
            ),
            role: LedgerEntryRole.primary,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Transaction and valuation amounts must be equal when they use '
                  'the same asset.',
            ),
          ),
        );
      },
    );

    test(
      'rejects different transaction and account quantities in one asset',
      () {
        // When / Then
        expect(
          () => LedgerEntry(
            accountId: accountId,
            transactionAmount: AssetAmount.outgoing(
              assetId: transactionAssetId,
              amount: Decimal.parse('10'),
            ),
            accountAmount: AssetAmount.outgoing(
              assetId: transactionAssetId,
              amount: Decimal.parse('9.99'),
            ),
            valuationAmount: AssetAmount.outgoing(
              assetId: valuationAssetId,
              amount: Decimal.parse('9.25'),
            ),
            role: LedgerEntryRole.primary,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Transaction and account amounts must be equal when they use '
                  'the same asset.',
            ),
          ),
        );
      },
    );

    test(
      'rejects an unknown amount paired with a known same-asset quantity',
      () {
        // When / Then
        expect(
          () => LedgerEntry(
            accountId: accountId,
            transactionAmount: AssetAmount.incoming(
              assetId: transactionAssetId,
              amount: Decimal.fromInt(-1),
            ),
            accountAmount: AssetAmount.incoming(
              assetId: accountAssetId,
              amount: Decimal.one,
            ),
            valuationAmount: AssetAmount.incoming(
              assetId: transactionAssetId,
              amount: Decimal.one,
            ),
            role: LedgerEntryRole.primary,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}
