@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('transactionRepositoryProvider', () {
    test('provides the in-memory transaction repository', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(transactionRepositoryProvider);

      // Then
      expect(repository, isA<InMemoryTransactionRepositoryImpl>());
    });
  });
}
