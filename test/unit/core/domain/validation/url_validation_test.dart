@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/validation/url_validation.dart';
import 'package:test/test.dart';

void main() {
  group('isValidHttpUrl', () {
    test('accepts absolute HTTP(S) URLs with a host', () {
      // Given / When
      final httpResult = isValidHttpUrl('http://example.com');
      final httpsResult = isValidHttpUrl('https://example.com/path');

      // Then
      expect(httpResult, isTrue);
      expect(httpsResult, isTrue);
    });

    test('trims surrounding whitespace', () {
      // Given / When
      final result = isValidHttpUrl('  https://example.com  ');

      // Then
      expect(result, isTrue);
    });

    test('rejects blank, relative, unsupported, and hostless URLs', () {
      // Given / When
      final results = [
        isValidHttpUrl('  '),
        isValidHttpUrl('/path'),
        isValidHttpUrl('ftp://example.com'),
        isValidHttpUrl('https://'),
      ];

      // Then
      expect(results, everyElement(isFalse));
    });
  });

  group('normalizeOptionalHttpUrl', () {
    test('returns null when the value is omitted', () {
      // Given / When
      final result = normalizeOptionalHttpUrl(null, 'remoteLogoUrl');

      // Then
      expect(result, isNull);
    });

    test('trims a valid URL', () {
      // Given / When
      final result = normalizeOptionalHttpUrl(
        '  https://example.com/logo.png  ',
        'remoteLogoUrl',
      );

      // Then
      expect(result, 'https://example.com/logo.png');
    });

    test('throws ArgumentError when the value is blank', () {
      // Given / When / Then
      expect(
        () => normalizeOptionalHttpUrl('  ', 'remoteLogoUrl'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'remoteLogoUrl',
          ),
        ),
      );
    });

    test('throws ArgumentError when the URL is not absolute HTTP(S)', () {
      // Given / When / Then
      expect(
        () => normalizeOptionalHttpUrl('ftp://example.com', 'remoteLogoUrl'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'remoteLogoUrl',
          ),
        ),
      );
    });
  });
}
