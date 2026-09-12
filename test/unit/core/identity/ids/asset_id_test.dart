import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('AssetId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'asset-123';

      final assetId = AssetId.fromString(value);

      expect(assetId.value, value);
    });

    test('fromString rejects empty and whitespace-only values', () {
      const invalidValues = ['', ' ', '\t', '\n'];

      for (final value in invalidValues) {
        expect(
          () => AssetId.fromString(value),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.invalidValue, 'invalidValue', value)
                .having((error) => error.name, 'name', 'value'),
          ),
          reason: 'Expected ${value.runes} to be rejected.',
        );
      }
    });

    test('round trips through dart_mappable serialization', () {
      final assetId = AssetId.fromString('asset-123');

      final decoded = AssetIdMapper.fromJson(assetId.toJson());

      expect(decoded, assetId);
    });

    test(
      'remains distinct from another typed identifier with the same value',
      () {
        final assetId = AssetId.fromString('same-id');
        final accountId = AccountId.fromString('same-id');

        expect(assetId, isNot(accountId));
        expect(assetId, isA<AssetId>());
        expect(accountId, isA<AccountId>());
      },
    );

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final assetId = AssetId.generate();
      final allowedCharacters = urlAlphabet.split('');

      expect(assetId.value, isNotEmpty);
      expect(assetId.value.split(''), everyElement(isIn(allowedCharacters)));
    });
  });
}
