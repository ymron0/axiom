import 'package:axiom/src/application/di/services/create_transaction_service_provider.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('createTransactionServiceProvider', () {
    test('provides the create transaction service', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final service = container.read(createTransactionServiceProvider);

      // Then
      expect(service, isA<CreateTransactionService>());
    });
  });
}
