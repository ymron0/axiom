import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:test/test.dart';

void main() {
  group('Settings', () {
    test('preserves the required typed valuation currency ID', () {
      // Given
      final valuationCurrencyId = AssetId.fromString('currency-eur');

      // When
      final settings = Settings(valuationCurrencyId: valuationCurrencyId);

      // Then
      expect(settings.valuationCurrencyId, same(valuationCurrencyId));
    });

    test('provides mapped value semantics without mutating the original', () {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
      );
      final equivalent = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
      );

      // When
      final changed = settings.copyWith(
        valuationCurrencyId: AssetId.fromString('currency-usd'),
      );

      // Then
      expect(settings, equivalent);
      expect(settings, isNot(changed));
      expect(settings.valuationCurrencyId.value, 'currency-eur');
      expect(changed.valuationCurrencyId.value, 'currency-usd');
    });

    test('round trips through dart_mappable serialization', () {
      // Given
      final settings = Settings(
        valuationCurrencyId: AssetId.fromString('currency-eur'),
      );

      // When
      final decoded = SettingsMapper.fromJson(settings.toJson());

      // Then
      expect(decoded, settings);
    });
  });
}
