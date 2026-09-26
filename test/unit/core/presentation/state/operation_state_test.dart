@Tags(['presentation'])
library;

import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_kind.dart';
import 'package:axiom/src/core/presentation/state/operation_state.dart';
import 'package:test/test.dart';

void main() {
  group('OperationState', () {
    test('idle exposes idle state only', () {
      const state = OperationIdle<String>();

      expect(state.isIdle, isTrue);
      expect(state.isInProgress, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isFailure, isFalse);
      expect(state.valueOrNull, isNull);
      expect(state.errorOrNull, isNull);
    });

    test('in-progress exposes running state only', () {
      const state = OperationInProgress<String>();

      expect(state.isIdle, isFalse);
      expect(state.isInProgress, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.isFailure, isFalse);
    });

    test('success exposes result value', () {
      const state = OperationSuccess<String>('saved');

      expect(state.isSuccess, isTrue);
      expect(state.valueOrNull, 'saved');
      expect(state.errorOrNull, isNull);
    });

    test('failure exposes presentation error', () {
      const error = PresentationFailure(
        kind: PresentationFailureKind.validation,
        title: 'Invalid',
        message: 'Check the value.',
      );

      const state = OperationFailure<String>(error);

      expect(state.isFailure, isTrue);
      expect(state.errorOrNull, same(error));
      expect(state.valueOrNull, isNull);
    });
  });
}
