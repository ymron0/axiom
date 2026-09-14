@Tags(['data', 'di'])
library;

import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('categoryRepositoryProvider', () {
    test('provides the in-memory category repository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(categoryRepositoryProvider),
        isA<InMemoryCategoryRepositoryImpl>(),
      );
    });
  });
}
