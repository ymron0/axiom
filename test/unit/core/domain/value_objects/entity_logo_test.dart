import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:test/test.dart';

void main() {
  group('EntityLogo', () {
    test('constructs an asset logo and exposes its source properties', () {
      // Given
      const path = 'assets/logos/bank.png';

      // When
      final logo = EntityLogo(source: EntityLogoSource.asset, value: path);

      // Then
      expect(logo.source, EntityLogoSource.asset);
      expect(logo.value, path);
      expect(logo.isAsset, isTrue);
      expect(logo.isRemote, isFalse);
    });

    test('constructs a remote logo and exposes its source properties', () {
      // Given
      const url = 'https://example.com/logo.png';

      // When
      final logo = EntityLogo(source: EntityLogoSource.remote, value: url);

      // Then
      expect(logo.source, EntityLogoSource.remote);
      expect(logo.value, url);
      expect(logo.isAsset, isFalse);
      expect(logo.isRemote, isTrue);
    });

    test('asset factory trims the supplied path', () {
      // Given / When
      final logo = EntityLogo.asset('  assets/logos/bank.png  ');

      // Then
      expect(logo.source, EntityLogoSource.asset);
      expect(logo.value, 'assets/logos/bank.png');
      expect(logo.isAsset, isTrue);
      expect(logo.isRemote, isFalse);
    });

    test('remote factory trims the supplied URL', () {
      // Given / When
      final logo = EntityLogo.remote('  https://example.com/logo.png  ');

      // Then
      expect(logo.source, EntityLogoSource.remote);
      expect(logo.value, 'https://example.com/logo.png');
      expect(logo.isAsset, isFalse);
      expect(logo.isRemote, isTrue);
    });

    test('rejects empty and whitespace-only values', () {
      // Given / When / Then
      for (final value in ['', ' ', '  \t\n  ']) {
        expect(
          () => EntityLogo(source: EntityLogoSource.asset, value: value),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'value')
                .having((error) => error.invalidValue, 'invalidValue', value),
          ),
          reason: 'Expected blank value to be rejected: ${value.codeUnits}',
        );
      }
    });

    test('compares logos by their mapped source and value', () {
      // Given
      final first = EntityLogo.asset('assets/logos/bank.png');
      final equivalent = EntityLogo(
        source: EntityLogoSource.asset,
        value: 'assets/logos/bank.png',
      );
      final differentSource = EntityLogo.remote('assets/logos/bank.png');
      final differentValue = EntityLogo.asset('assets/logos/card.png');

      // Then
      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(differentSource));
      expect(first, isNot(differentValue));
    });
  });
}
