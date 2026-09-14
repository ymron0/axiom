@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/restore_transaction_service_provider.dart';
import 'package:axiom/src/application/services/restore_transaction_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('restoreTransactionServiceProvider', () {
    test('provides the restore transaction service', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final service = container.read(restoreTransactionServiceProvider);

      // Then
      expect(service, isA<RestoreTransactionService>());
    });
  });
}
