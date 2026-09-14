@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/delete_category_service_provider.dart';
import 'package:axiom/src/application/services/delete_category_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('deleteCategoryServiceProvider', () {
    test('provides the category deletion service', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(deleteCategoryServiceProvider), isA<DeleteCategoryService>());
    });
  });
}
