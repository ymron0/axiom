import 'package:axiom/src/features/assets/domain/value_objects/asset_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('AssetId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'asset-123';

      final assetId = AssetId.fromString(value);

      expect(assetId.value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final assetId = AssetId.generate();
      final allowedCharacters = urlAlphabet.split('');

      expect(assetId.value, isNotEmpty);
      expect(
        assetId.value.split(''),
        everyElement(isIn(allowedCharacters)),
      );
    });
  });
}
