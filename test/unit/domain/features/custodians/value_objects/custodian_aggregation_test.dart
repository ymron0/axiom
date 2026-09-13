import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/custodian_aggregation.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianAggregation', () {
    final custodianId = CustodianId.fromString('custodian-1');
    final chf = AssetId.fromString('currency-chf');

    test('creates an aggregation with a known total', () {
      // Given
      final total = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse('1500'),
      );

      // When
      final aggregation = CustodianAggregation(
        custodianId: custodianId,
        total: total,
        accountCount: 3,
      );

      // Then
      expect(aggregation.custodianId, custodianId);
      expect(aggregation.total, total);
      expect(aggregation.accountCount, 3);
    });

    test('allows a negative aggregate total', () {
      // Given
      final total = AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse('500'),
      );

      // When
      final aggregation = CustodianAggregation(
        custodianId: custodianId,
        total: total,
        accountCount: 2,
      );

      // Then
      expect(aggregation.total.isOutgoing, isTrue);
      expect(aggregation.total.amount, Decimal.parse('500'));
    });

    test('allows an empty zero aggregation', () {
      // Given
      final total = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.zero,
      );

      // When
      final aggregation = CustodianAggregation(
        custodianId: custodianId,
        total: total,
        accountCount: 0,
      );

      // Then
      expect(aggregation.total.amount, Decimal.zero);
      expect(aggregation.accountCount, 0);
    });

    test('throws when total is unknown', () {
      // Given
      final total = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.fromInt(-1),
      );

      // When / Then
      expect(
        () => CustodianAggregation(
          custodianId: custodianId,
          total: total,
          accountCount: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when account count is negative', () {
      // Given
      final total = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.zero,
      );

      // When / Then
      expect(
        () => CustodianAggregation(
          custodianId: custodianId,
          total: total,
          accountCount: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
