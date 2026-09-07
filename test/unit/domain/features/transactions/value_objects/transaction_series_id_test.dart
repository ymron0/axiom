import 'package:axiom/src/features/transactions/domain/value_objects/transaction_series_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'transaction-series-123';
      expect(TransactionSeriesId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = TransactionSeriesId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
