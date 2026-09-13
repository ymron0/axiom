import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('AccountValuation', () {
    final accountId = AccountId.fromString('account-1');
    final custodianId = CustodianId.fromString('custodian-1');

    final eur = AssetId.fromString('currency-eur');
    final chf = AssetId.fromString('currency-chf');

    test('creates a positive valuation in different currencies', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('1000'),
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('935'),
      );

      // When
      final valuation = AccountValuation(
        accountId: accountId,
        custodianId: custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      );

      // Then
      expect(valuation.accountId, accountId);
      expect(valuation.custodianId, custodianId);
      expect(valuation.accountAmount, accountAmount);
      expect(valuation.valuationAmount, valuationAmount);
    });

    test('creates a negative valuation in different currencies', () {
      // Given
      final accountAmount = AssetAmount.outgoing(
        assetId: eur,
        amount: Decimal.parse('1000'),
      );

      final valuationAmount = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('935'),
      );

      // When
      final valuation = AccountValuation(
        accountId: accountId,
        custodianId: custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      );

      // Then
      expect(valuation.accountAmount.isOutgoing, isTrue);
      expect(valuation.valuationAmount.isOutgoing, isTrue);
    });

    test('allows zero amounts', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.zero,
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.zero,
      );

      // When
      final valuation = AccountValuation(
        accountId: accountId,
        custodianId: custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      );

      // Then
      expect(valuation.accountAmount.amount, Decimal.zero);
      expect(valuation.valuationAmount.amount, Decimal.zero);
    });

    test('allows equivalent zero amounts with different directions', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.zero,
      );

      final valuationAmount = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.zero,
      );

      // When
      final valuation = AccountValuation(
        accountId: accountId,
        custodianId: custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      );

      // Then
      expect(valuation.accountAmount.amount, Decimal.zero);
      expect(valuation.valuationAmount.amount, Decimal.zero);
    });

    test('allows identical amounts when both use the same asset', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('1200'),
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('1200'),
      );

      // When
      final valuation = AccountValuation(
        accountId: accountId,
        custodianId: custodianId,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
      );

      // Then
      expect(
        valuation.accountAmount.isEqualTo(valuation.valuationAmount),
        isTrue,
      );
    });

    test('throws when account amount is unknown', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.fromInt(-1),
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('935'),
      );

      // When / Then
      expect(
        () => AccountValuation(
          accountId: accountId,
          custodianId: custodianId,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when valuation amount is unknown', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('1000'),
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.fromInt(-1),
      );

      // When / Then
      expect(
        () => AccountValuation(
          accountId: accountId,
          custodianId: custodianId,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when one amount is zero and the other is non-zero', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.zero,
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('10'),
      );

      // When / Then
      expect(
        () => AccountValuation(
          accountId: accountId,
          custodianId: custodianId,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when non-zero amounts have different directions', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('1000'),
      );

      final valuationAmount = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('935'),
      );

      // When / Then
      expect(
        () => AccountValuation(
          accountId: accountId,
          custodianId: custodianId,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when same-asset amounts differ', () {
      // Given
      final accountAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('1000'),
      );

      final valuationAmount = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('999'),
      );

      // When / Then
      expect(
        () => AccountValuation(
          accountId: accountId,
          custodianId: custodianId,
          accountAmount: accountAmount,
          valuationAmount: valuationAmount,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}