@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_template_instantiation_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionTemplateInstantiationFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionTemplateInstantiationFailure(
        message: 'Invalid recurring transaction template.',
      );

      expect(failure.type, TransactionTemplateInstantiationFailure.typeId);
      expect(failure.message, 'Invalid recurring transaction template.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.isFailure, isTrue);
      expect(failure.isSuccess, isFalse);
      expect(failure.valueOrNull, isNull);
    });

    test('dispatches through the failure branch', () {
      const failure = TransactionTemplateInstantiationFailure();

      final result = failure.when<String>(
        success: (_) => 'success',
        failure: (_) => 'failure',
      );

      expect(result, 'failure');
    });
  });
}
