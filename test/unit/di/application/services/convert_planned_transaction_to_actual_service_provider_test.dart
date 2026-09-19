@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/convert_planned_transaction_to_actual_service_provider.dart';
import 'package:axiom/src/application/di/services/update_transaction_service_provider.dart';
import 'package:axiom/src/application/services/convert_planned_transaction_to_actual_service.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../mocks/category_repository_mock.dart';
import '../../../../mocks/jar_repository_mock.dart';
import '../../../../mocks/tag_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('convertPlannedTransactionToActualServiceProvider', () {
    test('provides the planned-to-actual workflow', () {
      final lookupRepository = MockTransactionRepository();
      final updateRepository = MockTransactionRepository();

      final allocationValidator = ValidateTransactionAllocationsService(
        getCategoryById: GetCategoryByIdUseCase(MockCategoryRepository()),
        getJarById: GetJarByIdUseCase(MockJarRepository()),
      );

      final tagValidator = ValidateTransactionTagsService(
        getTagsByIds: GetTagsByIdsUseCase(MockTagRepository()),
      );

      final updateService = UpdateTransactionService(
        getTransactionById: GetTransactionByIdUseCase(updateRepository),
        updateTransaction: UpdateTransactionUseCase(updateRepository),
        validateAllocations: allocationValidator,
        validateTags: tagValidator,
      );

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19)),
          ),
          getTransactionByIdUseCaseProvider.overrideWithValue(
            GetTransactionByIdUseCase(lookupRepository),
          ),
          updateTransactionServiceProvider.overrideWithValue(updateService),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(
        convertPlannedTransactionToActualServiceProvider,
      );

      expect(service, isA<ConvertPlannedTransactionToActualService>());
    });
  });
}
