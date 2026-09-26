@Tags(['presentation'])
library;

import 'package:axiom/src/core/presentation/validation/form_validators.dart';
import 'package:test/test.dart';

void main() {
  group('FormValidators.requiredText', () {
    test('rejects null and blank values', () {
      expect(FormValidators.requiredText(null), isNotNull);
      expect(FormValidators.requiredText(''), isNotNull);
      expect(FormValidators.requiredText('   '), isNotNull);
    });

    test('accepts non-empty text', () {
      expect(FormValidators.requiredText('Account'), isNull);
    });
  });

  group('FormValidators.decimalNumber', () {
    test('accepts dot decimal separator', () {
      expect(FormValidators.decimalNumber('12.50'), isNull);
    });

    test('accepts comma decimal separator', () {
      expect(FormValidators.decimalNumber('12,50'), isNull);
    });

    test('rejects invalid input', () {
      expect(FormValidators.decimalNumber('abc'), isNotNull);
    });

    test('allows empty optional value', () {
      expect(FormValidators.decimalNumber('', required: false), isNull);
    });
  });

  group('FormValidators.positiveDecimal', () {
    test('accepts positive amount', () {
      expect(FormValidators.positiveDecimal('0.01'), isNull);
    });

    test('rejects zero', () {
      expect(FormValidators.positiveDecimal('0'), isNotNull);
    });

    test('rejects negative amount', () {
      expect(FormValidators.positiveDecimal('-1'), isNotNull);
    });
  });

  group('FormValidators.nonNegativeDecimal', () {
    test('accepts zero', () {
      expect(FormValidators.nonNegativeDecimal('0'), isNull);
    });

    test('rejects negative amount', () {
      expect(FormValidators.nonNegativeDecimal('-0.01'), isNotNull);
    });
  });

  group('FormValidators.maxLength', () {
    test('accepts value within maximum', () {
      expect(FormValidators.maxLength('12345', 5), isNull);
    });

    test('rejects value exceeding maximum', () {
      expect(FormValidators.maxLength('123456', 5), isNotNull);
    });
  });

  group('FormValidators.combine', () {
    test('returns first validation failure', () {
      final validator = FormValidators.combine<String>([
        FormValidators.requiredText,
        (value) => FormValidators.maxLength(value, 5),
      ]);

      expect(validator(''), 'This field is required.');
      expect(validator('123456'), 'Use no more than 5 characters.');
      expect(validator('12345'), isNull);
    });
  });
}
