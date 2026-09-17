@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceAmountEnd', () {
    final assetId = AssetId.fromString('asset-123');

    test('rejects an unknown target amount', () {
      expect(
        () => RecurrenceAmountEnd(
          targetAmount: _amount(assetId, '-1'),
          completion: RecurrenceAmountCompletion.fullOccurrence,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'targetAmount')
              .having(
                (error) => error.message,
                'message',
                'Recurrence target amount must be known.',
              ),
        ),
      );
    });

    test('rejects a zero target amount', () {
      expect(
        () => RecurrenceAmountEnd(
          targetAmount: _amount(assetId, '0'),
          completion: RecurrenceAmountCompletion.exactTarget,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'targetAmount')
              .having(
                (error) => error.message,
                'message',
                'Recurrence target amount must be greater than zero.',
              ),
        ),
      );
    });

    test('accepts a positive target amount and preserves its configuration', () {
      final target = _amount(assetId, '100', outgoing: true);
      final end = RecurrenceAmountEnd(
        targetAmount: target,
        completion: RecurrenceAmountCompletion.exactTarget,
      );

      expect(end.targetAmount, same(target));
      expect(end.completion, RecurrenceAmountCompletion.exactTarget);
    });

    test('reports whether the target has been reached or exceeded', () {
      final end = _end(assetId, '100');

      expect(end.isReachedBy(_amount(assetId, '99')), isFalse);
      expect(end.isReachedBy(_amount(assetId, '100')), isTrue);
      expect(end.isReachedBy(_amount(assetId, '101')), isTrue);
    });

    test('resolves no next amount after the target has been reached', () {
      final end = _end(assetId, '100');

      expect(
        end.resolveNextAmount(
          accumulatedAmount: _amount(assetId, '100'),
          normalOccurrenceAmount: _amount(assetId, '25'),
        ),
        isNull,
      );
    });

    test('keeps a normal occurrence that fits within the remaining target', () {
      final end = _end(assetId, '100');
      final normal = _amount(assetId, '25');

      expect(
        end.resolveNextAmount(
          accumulatedAmount: _amount(assetId, '75'),
          normalOccurrenceAmount: normal,
        ),
        same(normal),
      );
    });

    test('keeps the full occurrence when full occurrence completion overshoots', () {
      final end = RecurrenceAmountEnd(
        targetAmount: _amount(assetId, '100'),
        completion: RecurrenceAmountCompletion.fullOccurrence,
      );
      final normal = _amount(assetId, '30');

      expect(
        end.resolveNextAmount(
          accumulatedAmount: _amount(assetId, '75'),
          normalOccurrenceAmount: normal,
        ),
        same(normal),
      );
    });

    test('reduces an overshooting occurrence to the exact remaining target', () {
      final end = RecurrenceAmountEnd(
        targetAmount: _amount(assetId, '100', outgoing: true),
        completion: RecurrenceAmountCompletion.exactTarget,
      );

      final resolved = end.resolveNextAmount(
        accumulatedAmount: _amount(assetId, '75', outgoing: true),
        normalOccurrenceAmount: _amount(assetId, '30', outgoing: true),
      );

      expect(resolved?.assetId, same(assetId));
      expect(resolved?.amount, Decimal.parse('25'));
      expect(resolved?.direction, AssetAmountDirection.outgoing);
    });

    test('reports whether an occurrence completes the target', () {
      final end = _end(assetId, '100');

      expect(
        end.completesWith(
          accumulatedAmount: _amount(assetId, '75'),
          occurrenceAmount: _amount(assetId, '25'),
        ),
        isTrue,
      );
      expect(
        end.completesWith(
          accumulatedAmount: _amount(assetId, '75'),
          occurrenceAmount: _amount(assetId, '24'),
        ),
        isFalse,
      );
    });

    test('returns the positive remaining amount or zero after completion', () {
      final end = _end(assetId, '100');

      expect(end.remainingAfter(_amount(assetId, '40')).amount, Decimal.parse('60'));
      expect(end.remainingAfter(_amount(assetId, '100')).amount, Decimal.zero);
      expect(end.remainingAfter(_amount(assetId, '125')).amount, Decimal.zero);
    });

    test('rejects unknown progress amounts', () {
      final end = _end(assetId, '100');
      final unknown = _amount(assetId, '-1');

      expect(
        () => end.isReachedBy(unknown),
        _progressError(
          parameterName: 'accumulatedAmount',
          message: 'Recurrence amount progress must use known amounts.',
        ),
      );
      expect(
        () => end.resolveNextAmount(
          accumulatedAmount: _amount(assetId, '10'),
          normalOccurrenceAmount: unknown,
        ),
        _progressError(
          parameterName: 'normalOccurrenceAmount',
          message: 'Recurrence amount progress must use known amounts.',
        ),
      );
      expect(
        () => end.completesWith(
          accumulatedAmount: _amount(assetId, '10'),
          occurrenceAmount: unknown,
        ),
        _progressError(
          parameterName: 'occurrenceAmount',
          message: 'Recurrence amount progress must use known amounts.',
        ),
      );
      expect(
        () => end.remainingAfter(unknown),
        _progressError(
          parameterName: 'accumulatedAmount',
          message: 'Recurrence amount progress must use known amounts.',
        ),
      );
    });

    test('rejects progress amounts using a different asset', () {
      final end = _end(assetId, '100');
      final otherAsset = AssetId.fromString('asset-456');

      expect(
        () => end.isReachedBy(_amount(otherAsset, '10')),
        _progressError(
          parameterName: 'accumulatedAmount',
          message: 'Recurrence amount progress must use the target asset.',
        ),
      );
      expect(
        () => end.resolveNextAmount(
          accumulatedAmount: _amount(assetId, '10'),
          normalOccurrenceAmount: _amount(otherAsset, '10'),
        ),
        _progressError(
          parameterName: 'normalOccurrenceAmount',
          message: 'Recurrence amount progress must use the target asset.',
        ),
      );
      expect(
        () => end.completesWith(
          accumulatedAmount: _amount(assetId, '10'),
          occurrenceAmount: _amount(otherAsset, '10'),
        ),
        _progressError(
          parameterName: 'occurrenceAmount',
          message: 'Recurrence amount progress must use the target asset.',
        ),
      );
      expect(
        () => end.remainingAfter(_amount(otherAsset, '10')),
        _progressError(
          parameterName: 'accumulatedAmount',
          message: 'Recurrence amount progress must use the target asset.',
        ),
      );
    });

    test('rejects progress amounts using a different direction', () {
      final end = _end(assetId, '100');
      final outgoing = _amount(assetId, '10', outgoing: true);

      expect(
        () => end.isReachedBy(outgoing),
        _progressError(
          parameterName: 'accumulatedAmount',
          message: 'Recurrence amount progress must use the target direction.',
        ),
      );
      expect(
        () => end.resolveNextAmount(
          accumulatedAmount: _amount(assetId, '10'),
          normalOccurrenceAmount: outgoing,
        ),
        _progressError(
          parameterName: 'normalOccurrenceAmount',
          message: 'Recurrence amount progress must use the target direction.',
        ),
      );
      expect(
        () => end.completesWith(
          accumulatedAmount: _amount(assetId, '10'),
          occurrenceAmount: outgoing,
        ),
        _progressError(
          parameterName: 'occurrenceAmount',
          message: 'Recurrence amount progress must use the target direction.',
        ),
      );
      expect(
        () => end.remainingAfter(outgoing),
        _progressError(
          parameterName: 'accumulatedAmount',
          message: 'Recurrence amount progress must use the target direction.',
        ),
      );
    });
  });
}

AssetAmount _amount(AssetId assetId, String value, {bool outgoing = false}) {
  return AssetAmount(
    assetId: assetId,
    amount: Decimal.parse(value),
    direction: outgoing
        ? AssetAmountDirection.outgoing
        : AssetAmountDirection.incoming,
  );
}

RecurrenceAmountEnd _end(AssetId assetId, String target, {bool outgoing = false}) {
  return RecurrenceAmountEnd(
    targetAmount: _amount(assetId, target, outgoing: outgoing),
    completion: RecurrenceAmountCompletion.exactTarget,
  );
}

Matcher _progressError({
  required String parameterName,
  required String message,
}) {
  return throwsA(
    isA<ArgumentError>()
        .having((error) => error.name, 'name', parameterName)
        .having((error) => error.message, 'message', message),
  );
}
