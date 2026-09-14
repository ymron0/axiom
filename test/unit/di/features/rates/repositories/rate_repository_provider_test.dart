@Tags(['data', 'di'])
library;

import 'package:axiom/src/features/rates/data/repositories/in_memory_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('rateRepositoryProvider', () {
    test('provides the in-memory rate repository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(rateRepositoryProvider);

      expect(repository, isA<InMemoryRateRepositoryImpl>());
    });
  });
}
