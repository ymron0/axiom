import 'package:axiom/src/features/rates/data/exceptions/exchange_rate_data_source_exception.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('UnexpectedExchangeRateBaseCurrencyException', () {
    test('exposes expected and actual codes', () {
      // When
      final exception = UnexpectedExchangeRateBaseCurrencyException(
        expectedCode: 'USD',
        actualCode: 'EUR',
      );

      // Then
      expect(exception.expectedCode, 'USD');
      expect(exception.actualCode, 'EUR');
      expect(
        exception.message,
        'Expected provider base currency USD, but received EUR.',
      );
    });

    test('toString includes type and message', () {
      // Given
      final exception = UnexpectedExchangeRateBaseCurrencyException(
        expectedCode: 'USD',
        actualCode: 'EUR',
      );

      // When
      final description = exception.toString();

      // Then
      expect(
        description,
        'UnexpectedExchangeRateBaseCurrencyException: '
        'Expected provider base currency USD, but received EUR.',
      );
    });
  });

  group('MissingExchangeRateSourceValueException', () {
    test('exposes missing currency code', () {
      // When
      final exception = MissingExchangeRateSourceValueException(
        currencyCode: 'EUR',
      );

      // Then
      expect(exception.currencyCode, 'EUR');
      expect(
        exception.message,
        'The provider did not return an exchange rate for EUR.',
      );
    });

    test('toString includes type and message', () {
      // Given
      final exception = MissingExchangeRateSourceValueException(
        currencyCode: 'EUR',
      );

      // When
      final description = exception.toString();

      // Then
      expect(
        description,
        'MissingExchangeRateSourceValueException: '
        'The provider did not return an exchange rate for EUR.',
      );
    });
  });

  group('InvalidExchangeRateSourceValueException', () {
    test('exposes currency code and invalid value', () {
      // Given
      final value = Decimal.parse('-0.1');

      // When
      final exception = InvalidExchangeRateSourceValueException(
        currencyCode: 'EUR',
        value: value,
      );

      // Then
      expect(exception.currencyCode, 'EUR');
      expect(exception.value, value);
      expect(
        exception.message,
        'The provider returned an invalid exchange rate for EUR: -0.1.',
      );
    });

    test('toString includes type and message', () {
      // Given
      final exception = InvalidExchangeRateSourceValueException(
        currencyCode: 'EUR',
        value: Decimal.zero,
      );

      // When
      final description = exception.toString();

      // Then
      expect(
        description,
        'InvalidExchangeRateSourceValueException: '
        'The provider returned an invalid exchange rate for EUR: 0.',
      );
    });
  });

  group('DuplicateExchangeRateProviderCodeException', () {
    test('exposes duplicated currency code', () {
      // When
      final exception = DuplicateExchangeRateProviderCodeException(
        currencyCode: 'EUR',
      );

      // Then
      expect(exception.currencyCode, 'EUR');
      expect(
        exception.message,
        'The provider returned duplicate currency code EUR.',
      );
    });

    test('toString includes type and message', () {
      // Given
      final exception = DuplicateExchangeRateProviderCodeException(
        currencyCode: 'EUR',
      );

      // When
      final description = exception.toString();

      // Then
      expect(
        description,
        'DuplicateExchangeRateProviderCodeException: '
        'The provider returned duplicate currency code EUR.',
      );
    });
  });
}
