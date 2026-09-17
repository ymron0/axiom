@Tags(['data'])
library;

import 'package:axiom/src/features/rates/data/failures/market_price_data_source_failure.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_invalid_response_failure.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_not_found_failure.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_source_unavailable_failure.dart';
import 'package:test/test.dart';

void main() {
  group('Market price data-source failures', () {
    test('MarketPriceNotFoundFailure exposes its typed contract', () {
      // Given
      const failure = MarketPriceNotFoundFailure(message: 'Price not found.');

      // Then
      expect(failure, isA<MarketPriceDataSourceFailure>());
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MarketPriceNotFoundFailure.typeId);
      expect(failure.message, 'Price not found.');
      expect(failure.isFailure, isTrue);
      expect(failure.isSuccess, isFalse);
    });

    test('MarketPriceSourceUnavailableFailure exposes its typed contract', () {
      // Given
      const failure = MarketPriceSourceUnavailableFailure(
        message: 'Provider unavailable.',
      );

      // Then
      expect(failure, isA<MarketPriceDataSourceFailure>());
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MarketPriceSourceUnavailableFailure.typeId);
      expect(failure.message, 'Provider unavailable.');
    });

    test('MarketPriceInvalidResponseFailure exposes its typed contract', () {
      // Given
      const failure = MarketPriceInvalidResponseFailure(
        message: 'Malformed provider response.',
      );

      // Then
      expect(failure, isA<MarketPriceDataSourceFailure>());
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, MarketPriceInvalidResponseFailure.typeId);
      expect(failure.message, 'Malformed provider response.');
    });
  });
}
