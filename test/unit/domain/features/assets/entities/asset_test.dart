import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:test/test.dart';

void main() {
  group('Asset', () {
    test('preserves all supplied metadata through Currency', () {
      // Given
      final assetId = AssetId.fromString('currency-eur');
      final assetCode = AssetCode('EUR');

      // When
      final currency = Currency(
        id: assetId,
        name: 'Euro',
        code: assetCode,
        symbol: '€',
        remoteLogoUrl: 'https://example.com/euro.png',
        bundledLogoAsset: 'assets/logos/euro.png',
        decimalPlaces: 2,
      );

      // Then
      expect(currency, isA<Asset>());
      expect(currency.id, same(assetId));
      expect(currency.name, 'Euro');
      expect(currency.code, same(assetCode));
      expect(currency.symbol, '€');
      expect(currency.remoteLogoUrl, 'https://example.com/euro.png');
      expect(currency.bundledLogoAsset, 'assets/logos/euro.png');
      expect(currency.decimalPlaces, 2);
    });

    test('represents a concrete currency asset subtype', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        decimalPlaces: 2,
      );

      // Then
      expect(currency, isA<Currency>());
      expect(currency, isA<Asset>());
    });

    test('round trips through dart_mappable serialization', () {
      // Given
      final currency = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        symbol: '€',
        decimalPlaces: 2,
      );

      // When
      final decoded = CurrencyMapper.fromJson(currency.toJson());

      // Then
      expect(decoded, currency);
    });

    test('compares currencies by their mapped domain values', () {
      // Given
      final first = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        decimalPlaces: 2,
      );
      final equivalent = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        decimalPlaces: 2,
      );
      final different = Currency(
        id: AssetId.fromString('currency-usd'),
        name: 'US Dollar',
        code: AssetCode('USD'),
        decimalPlaces: 2,
      );

      // Then
      expect(first, equivalent);
      expect(first, isNot(different));
    });

    test('allows optional metadata to be omitted through Currency', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-jpy'),
        name: 'Japanese Yen',
        code: AssetCode('JPY'),
        decimalPlaces: 0,
      );

      // Then
      expect(currency.symbol, isNull);
      expect(currency.remoteLogoUrl, isNull);
      expect(currency.bundledLogoAsset, isNull);
      expect(currency.decimalPlaces, 0);
    });

    test('accepts any three ASCII letters as the currency code', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-chf'),
        name: 'Swiss Franc',
        code: AssetCode('CHF'),
        decimalPlaces: 2,
      );

      // Then
      expect(currency.code.value, 'CHF');
    });

    test('trims the display name and symbol', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-eur'),
        name: ' Euro ',
        code: AssetCode('EUR'),
        symbol: ' € ',
        decimalPlaces: 2,
      );

      // Then
      expect(currency.name, 'Euro');
      expect(currency.symbol, '€');
    });

    test('normalizes optional metadata through the shared text validator', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        symbol: ' € ',
        bundledLogoAsset: ' assets/logos/euro.png ',
        decimalPlaces: 2,
      );

      // Then
      expect(currency.symbol, '€');
      expect(currency.bundledLogoAsset, 'assets/logos/euro.png');
    });

    test('rejects a blank display name', () {
      // Given / When / Then
      expect(
        () => Currency(
          id: AssetId.fromString('currency-eur'),
          name: '  ',
          code: AssetCode('EUR'),
          decimalPlaces: 2,
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'name'),
        ),
      );
    });

    test('rejects a negative decimal place count', () {
      // Given / When / Then
      expect(
        () => Currency(
          id: AssetId.fromString('currency-eur'),
          name: 'Euro',
          code: AssetCode('EUR'),
          decimalPlaces: -1,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'decimalPlaces',
          ),
        ),
      );
    });

    test('allows decimal place counts above 18', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        decimalPlaces: 19,
      );

      // Then
      expect(currency.decimalPlaces, 19);
    });

    test('rejects a blank optional symbol', () {
      // Given / When / Then
      expect(
        () => Currency(
          id: AssetId.fromString('currency-eur'),
          name: 'Euro',
          code: AssetCode('EUR'),
          symbol: '  ',
          decimalPlaces: 2,
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'symbol'),
        ),
      );
    });

    test('rejects blank optional logo metadata', () {
      // Given / When / Then
      for (final field in ['remoteLogoUrl', 'bundledLogoAsset']) {
        expect(
          () => Currency(
            id: AssetId.fromString('currency-eur'),
            name: 'Euro',
            code: AssetCode('EUR'),
            remoteLogoUrl: field == 'remoteLogoUrl' ? '  ' : null,
            bundledLogoAsset: field == 'bundledLogoAsset' ? '  ' : null,
            decimalPlaces: 2,
          ),
          throwsA(
            isA<ArgumentError>().having((error) => error.name, 'name', field),
          ),
          reason: 'Expected $field to reject blank input.',
        );
      }
    });

    test('rejects an invalid remote logo URL', () {
      // Given / When / Then
      for (final value in [
        'example.com/logo.png',
        'ftp://example.com/logo.png',
      ]) {
        expect(
          () => Currency(
            id: AssetId.fromString('currency-eur'),
            name: 'Euro',
            code: AssetCode('EUR'),
            remoteLogoUrl: value,
            decimalPlaces: 2,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'remoteLogoUrl',
            ),
          ),
          reason: 'Expected $value to be rejected.',
        );
      }
    });

    test('trims valid logo metadata', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-eur'),
        name: 'Euro',
        code: AssetCode('EUR'),
        remoteLogoUrl: ' https://example.com/euro.png ',
        bundledLogoAsset: ' assets/logos/euro.png ',
        decimalPlaces: 2,
      );

      // Then
      expect(currency.remoteLogoUrl, 'https://example.com/euro.png');
      expect(currency.bundledLogoAsset, 'assets/logos/euro.png');
    });

    test('keeps identity independent from display metadata', () {
      // Given
      final assetId = AssetId.fromString('currency-eur');
      final first = Currency(
        id: assetId,
        name: 'Euro',
        code: AssetCode('EUR'),
        symbol: '€',
        decimalPlaces: 2,
      );
      final second = Currency(
        id: assetId,
        name: 'Euro (updated display name)',
        code: AssetCode('EUR'),
        symbol: '€',
        decimalPlaces: 2,
      );

      // Then
      expect(first.id, second.id);
      expect(first.name, isNot(second.name));
    });

    test('rejects currency codes that are not exactly three letters', () {
      // Given / When / Then
      for (final value in ['EU', 'EURO', 'EU1', '€UR']) {
        expect(
          () => Currency(
            id: AssetId.fromString('currency-invalid'),
            name: 'Invalid currency',
            code: AssetCode(value),
            decimalPlaces: 2,
          ),
          throwsA(
            isA<ArgumentError>().having((error) => error.name, 'name', 'code'),
          ),
          reason: 'Expected $value to be rejected.',
        );
      }
    });
  });
}
