@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../../mocks/get_jar_by_id_use_case_mock.dart';

void main() {
  group('validateTransactionAllocationsServiceProvider', () {
    test('uses the configured category and jar lookup use cases', () {
      // Given
      final getCategoryById = MockGetCategoryByIdUseCase();
      final getJarById = MockGetJarByIdUseCase();

      final container = ProviderContainer(
        overrides: [
          getCategoryByIdUseCaseProvider.overrideWithValue(getCategoryById),
          getJarByIdUseCaseProvider.overrideWithValue(getJarById),
        ],
      );
      addTearDown(container.dispose);

      // When
      final service = container.read(
        validateTransactionAllocationsServiceProvider,
      );

      // Then
      expect(service, isNotNull);
    });
  });
}
