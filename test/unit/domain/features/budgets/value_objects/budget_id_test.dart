import 'package:axiom/src/core/identity/ids/budget_id.dart';
import 'package:nanoid/nanoid.dart';
import 'package:test/test.dart';

void main() {
  group('BudgetId', () {
    test('fromString preserves the supplied identifier value', () {
      const value = 'budget-123';
      expect(BudgetId.fromString(value).value, value);
    });

    test('generate uses only characters from the Nano ID URL alphabet', () {
      final id = BudgetId.generate();
      expect(id.value, isNotEmpty);
      expect(id.value.split(''), everyElement(isIn(urlAlphabet.split(''))));
    });
  });
}
