@Tags(['domain'])
library;

import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeTagName', () {
    test('trims surrounding whitespace', () {
      expect(normalizeTagName('  Business  '), 'Business');
    });

    test('collapses consecutive internal whitespace', () {
      expect(normalizeTagName('Business   Travel'), 'Business Travel');

      expect(normalizeTagName('Business\t\nTravel'), 'Business Travel');
    });

    test('preserves display casing', () {
      expect(normalizeTagName('VAT Refund'), 'VAT Refund');
    });

    test('rejects blank names', () {
      expect(
        () => normalizeTagName(' \t\n '),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'name'),
        ),
      );
    });
  });

  group('tagNameKey', () {
    test('is case insensitive', () {
      expect(tagNameKey('Business Trip'), tagNameKey('BUSINESS TRIP'));
    });

    test('ignores insignificant whitespace', () {
      expect(tagNameKey(' Business   Trip '), tagNameKey('business trip'));
    });

    test('distinguishes materially different names', () {
      expect(tagNameKey('business'), isNot(tagNameKey('personal')));
    });
  });
}
