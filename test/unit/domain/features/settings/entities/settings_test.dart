@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:test/test.dart';

void main() {
  group('Settings', () {
    test('allows permissive transaction policies by default', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
      );

      expect(settings.allowOverbudgetTransactions, isTrue);
      expect(settings.allowNegativeJarBalances, isTrue);
    });

    test('supports disabling overbudget transactions', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
        allowOverbudgetTransactions: false,
      );

      expect(settings.allowOverbudgetTransactions, isFalse);
      expect(settings.allowNegativeJarBalances, isTrue);
    });

    test('supports disabling negative jar balances', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
        allowNegativeJarBalances: false,
      );

      expect(settings.allowOverbudgetTransactions, isTrue);
      expect(settings.allowNegativeJarBalances, isFalse);
    });

    test('preserves the required typed valuation currency ID', () {
      final valuationCurrencyId = AssetId.fromString('currency-eur');

      final settings = Settings(valuationCurrencyId: valuationCurrencyId);

      expect(settings.valuationCurrencyId, same(valuationCurrencyId));
    });

    test('copyWith can change only transaction policies', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
      );

      final changed = settings.copyWith(
        allowOverbudgetTransactions: false,
        allowNegativeJarBalances: false,
      );

      expect(changed.valuationCurrencyId, settings.valuationCurrencyId);

      expect(settings.allowOverbudgetTransactions, isTrue);
      expect(settings.allowNegativeJarBalances, isTrue);

      expect(changed.allowOverbudgetTransactions, isFalse);
      expect(changed.allowNegativeJarBalances, isFalse);
    });

    test('provides mapped value semantics without mutating the original', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
        allowOverbudgetTransactions: true,
        allowNegativeJarBalances: true,
      );

      final equivalent = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
        allowOverbudgetTransactions: true,
        allowNegativeJarBalances: true,
      );

      final changed = settings.copyWith(allowNegativeJarBalances: false);

      expect(settings, equivalent);
      expect(settings, isNot(changed));
    });

    test('round trips through dart_mappable serialization', () {
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
        allowOverbudgetTransactions: false,
        allowNegativeJarBalances: false,
      );

      final decoded = SettingsMapper.fromJson(settings.toJson());

      expect(decoded, settings);
      expect(decoded.allowOverbudgetTransactions, isFalse);
      expect(decoded.allowNegativeJarBalances, isFalse);
    });
  });
}
