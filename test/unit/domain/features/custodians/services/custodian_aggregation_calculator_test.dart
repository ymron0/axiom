import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/services/custodian_aggregation_calculator.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianAggregationCalculator', () {
    const calculator = CustodianAggregationCalculator();

    final custodianId = CustodianId.fromString('custodian-1');
    final otherCustodianId = CustodianId.fromString('custodian-2');

    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');
    final usd = AssetId.fromString('currency-usd');

    AccountValuation valuation({
      required String accountId,
      required AssetId accountAssetId,
      required String accountAmount,
      required String valuationAmount,
      bool outgoing = false,
      CustodianId? custodian,
      AssetId? valuationAssetId,
    }) {
      final resolvedValuationAssetId = valuationAssetId ?? chf;

      return AccountValuation(
        accountId: AccountId.fromString(accountId),
        custodianId: custodian ?? custodianId,
        accountAmount: outgoing
            ? AssetAmount.outgoing(
                assetId: accountAssetId,
                amount: Decimal.parse(accountAmount),
              )
            : AssetAmount.incoming(
                assetId: accountAssetId,
                amount: Decimal.parse(accountAmount),
              ),
        valuationAmount: outgoing
            ? AssetAmount.outgoing(
                assetId: resolvedValuationAssetId,
                amount: Decimal.parse(valuationAmount),
              )
            : AssetAmount.incoming(
                assetId: resolvedValuationAssetId,
                amount: Decimal.parse(valuationAmount),
              ),
      );
    }

    test('returns zero in the valuation currency for no accounts', () {
      // When
      final result = calculator.calculate(
        custodianId: custodianId,
        valuationCurrencyId: chf,
        accountValuations: const [],
      );

      // Then
      expect(result.custodianId, custodianId);
      expect(result.total.assetId, chf);
      expect(result.total.amount, Decimal.zero);
      expect(result.total.isIncoming, isTrue);
      expect(result.accountCount, 0);
    });

    test('returns the valuation amount of one account', () {
      // Given
      final account = valuation(
        accountId: 'account-1',
        accountAssetId: eur,
        accountAmount: '1000',
        valuationAmount: '935',
      );

      // When
      final result = calculator.calculate(
        custodianId: custodianId,
        valuationCurrencyId: chf,
        accountValuations: [account],
      );

      // Then
      expect(result.total.assetId, chf);
      expect(result.total.amount, Decimal.parse('935'));
      expect(result.total.isIncoming, isTrue);
      expect(result.accountCount, 1);
    });

    test('aggregates accounts with different denomination assets', () {
      // Given
      final accounts = [
        valuation(
          accountId: 'account-eur',
          accountAssetId: eur,
          accountAmount: '1000',
          valuationAmount: '935',
        ),
        valuation(
          accountId: 'account-usd',
          accountAssetId: usd,
          accountAmount: '500',
          valuationAmount: '400',
        ),
        valuation(
          accountId: 'account-chf',
          accountAssetId: chf,
          accountAmount: '2000',
          valuationAmount: '2000',
        ),
      ];

      // When
      final result = calculator.calculate(
        custodianId: custodianId,
        valuationCurrencyId: chf,
        accountValuations: accounts,
      );

      // Then
      expect(result.total.assetId, chf);
      expect(result.total.amount, Decimal.parse('3335'));
      expect(result.total.isIncoming, isTrue);
      expect(result.accountCount, 3);
    });

    test('subtracts negative account valuations', () {
      // Given
      final accounts = [
        valuation(
          accountId: 'account-current',
          accountAssetId: chf,
          accountAmount: '4200',
          valuationAmount: '4200',
        ),
        valuation(
          accountId: 'account-savings',
          accountAssetId: eur,
          accountAmount: '13000',
          valuationAmount: '12000',
        ),
        valuation(
          accountId: 'account-credit',
          accountAssetId: usd,
          accountAmount: '900',
          valuationAmount: '800',
          outgoing: true,
        ),
      ];

      // When
      final result = calculator.calculate(
        custodianId: custodianId,
        valuationCurrencyId: chf,
        accountValuations: accounts,
      );

      // Then
      expect(result.total.assetId, chf);
      expect(result.total.amount, Decimal.parse('15400'));
      expect(result.total.isIncoming, isTrue);
      expect(result.accountCount, 3);
    });

    test('can produce an outgoing aggregate total', () {
      // Given
      final accounts = [
        valuation(
          accountId: 'account-cash',
          accountAssetId: chf,
          accountAmount: '500',
          valuationAmount: '500',
        ),
        valuation(
          accountId: 'account-credit',
          accountAssetId: usd,
          accountAmount: '1700',
          valuationAmount: '1500',
          outgoing: true,
        ),
      ];

      // When
      final result = calculator.calculate(
        custodianId: custodianId,
        valuationCurrencyId: chf,
        accountValuations: accounts,
      );

      // Then
      expect(result.total.assetId, chf);
      expect(result.total.amount, Decimal.parse('1000'));
      expect(result.total.isOutgoing, isTrue);
      expect(result.accountCount, 2);
    });

    test('includes zero-valued accounts in the account count', () {
      // Given
      final accounts = [
        valuation(
          accountId: 'account-1',
          accountAssetId: chf,
          accountAmount: '100',
          valuationAmount: '100',
        ),
        valuation(
          accountId: 'account-2',
          accountAssetId: eur,
          accountAmount: '0',
          valuationAmount: '0',
        ),
      ];

      // When
      final result = calculator.calculate(
        custodianId: custodianId,
        valuationCurrencyId: chf,
        accountValuations: accounts,
      );

      // Then
      expect(result.total.amount, Decimal.parse('100'));
      expect(result.accountCount, 2);
    });

    test('throws when an account belongs to another custodian', () {
      // Given
      final accounts = [
        valuation(
          accountId: 'account-1',
          accountAssetId: chf,
          accountAmount: '100',
          valuationAmount: '100',
        ),
        valuation(
          accountId: 'account-2',
          accountAssetId: eur,
          accountAmount: '200',
          valuationAmount: '180',
          custodian: otherCustodianId,
        ),
      ];

      // When / Then
      expect(
        () => calculator.calculate(
          custodianId: custodianId,
          valuationCurrencyId: chf,
          accountValuations: accounts,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when a valuation uses another valuation currency', () {
      // Given
      final account = valuation(
        accountId: 'account-1',
        accountAssetId: eur,
        accountAmount: '100',
        valuationAmount: '110',
        valuationAssetId: usd,
      );

      // When / Then
      expect(
        () => calculator.calculate(
          custodianId: custodianId,
          valuationCurrencyId: chf,
          accountValuations: [account],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the same account appears more than once', () {
      // Given
      final accounts = [
        valuation(
          accountId: 'account-1',
          accountAssetId: eur,
          accountAmount: '100',
          valuationAmount: '95',
        ),
        valuation(
          accountId: 'account-1',
          accountAssetId: eur,
          accountAmount: '200',
          valuationAmount: '190',
        ),
      ];

      // When / Then
      expect(
        () => calculator.calculate(
          custodianId: custodianId,
          valuationCurrencyId: chf,
          accountValuations: accounts,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}