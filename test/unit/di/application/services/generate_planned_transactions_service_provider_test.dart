@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/generate_planned_transactions_service_provider.dart';
import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('generatePlannedTransactionsServiceProvider', () {
    test('provides the planned transaction generator', () {
      // Given
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19)),
          ),
        ],
      );

      addTearDown(container.dispose);

      // When
      final service = container.read(
        generatePlannedTransactionsServiceProvider,
      );

      // Then
      expect(service, isA<GeneratePlannedTransactionsService>());
    });
  });
}
