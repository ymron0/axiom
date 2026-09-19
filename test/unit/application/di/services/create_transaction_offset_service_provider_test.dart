@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/create_transaction_offset_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/services/create_transaction_offset_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_offset_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_offset_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('createTransactionOffsetServiceProvider', () {
    test('provides the create transaction offset service', () {
      // Given
      final repository = MockTransactionRepository();
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 1, 1)),
          ),
          getTransactionByIdUseCaseProvider.overrideWithValue(
            GetTransactionByIdUseCase(repository),
          ),
          createTransactionOffsetUseCaseProvider.overrideWithValue(
            CreateTransactionOffsetUseCase(repository: repository),
          ),
          validateTransactionAllocationsServiceProvider.overrideWithValue(
            ValidateTransactionAllocationsService(
              getCategoryById: MockGetCategoryByIdUseCase(),
              getJarById: MockGetJarByIdUseCase(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      final service = container.read(createTransactionOffsetServiceProvider);

      // Then
      expect(service, isA<CreateTransactionOffsetService>());
    });
  });
}
