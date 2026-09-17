@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/custodian_summary.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianSummary', () {
    final custodianId = CustodianId.fromString('custodian-summary');
    final chf = AssetId.fromString('asset-chf');
    final eur = AssetId.fromString('asset-eur');

    test('retains custodian identity, account count, and balances', () {
      // Given
      final balances = {
        chf: Decimal.parse('100'),
        eur: Decimal.parse('50'),
      };

      // When
      final summary = CustodianSummary(
        custodianId: custodianId,
        accountCount: 2,
        balancesByAsset: balances,
      );

      // Then
      expect(summary.custodianId, custodianId);
      expect(summary.accountCount, 2);
      expect(summary.balanceFor(chf), Decimal.parse('100'));
      expect(summary.balanceFor(eur), Decimal.parse('50'));
    });

    test('returns zero for an asset absent from the summary', () {
      // Given
      final summary = CustodianSummary(
        custodianId: custodianId,
        accountCount: 1,
        balancesByAsset: {
          chf: Decimal.parse('100'),
        },
      );

      // When
      final balance = summary.balanceFor(eur);

      // Then
      expect(balance, Decimal.zero);
    });

    test('rejects a negative account count', () {
      // When / Then
      expect(
        () => CustodianSummary(
          custodianId: custodianId,
          accountCount: -1,
          balancesByAsset: const {},
        ),
        throwsArgumentError,
      );
    });

    test('defensively copies the supplied balance map', () {
      // Given
      final balances = <AssetId, Decimal>{
        chf: Decimal.parse('100'),
      };

      final summary = CustodianSummary(
        custodianId: custodianId,
        accountCount: 1,
        balancesByAsset: balances,
      );

      // When
      balances[chf] = Decimal.parse('999');

      // Then
      expect(summary.balanceFor(chf), Decimal.parse('100'));
    });

    test('exposes an unmodifiable balance map', () {
      // Given
      final summary = CustodianSummary(
        custodianId: custodianId,
        accountCount: 1,
        balancesByAsset: {
          chf: Decimal.parse('100'),
        },
      );

      // When / Then
      expect(
        () => summary.balancesByAsset[chf] = Decimal.parse('999'),
        throwsUnsupportedError,
      );
    });
  });
}