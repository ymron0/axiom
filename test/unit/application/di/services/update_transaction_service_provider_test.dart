@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/update_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_tags_service_provider.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../../mocks/tag_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('updateTransactionServiceProvider', () {
    test('provides the update transaction service', () {
      final repository = MockTransactionRepository();

      final container = ProviderContainer(
        overrides: [
          getTransactionByIdUseCaseProvider.overrideWithValue(
            GetTransactionByIdUseCase(repository),
          ),
          updateTransactionUseCaseProvider.overrideWithValue(
            UpdateTransactionUseCase(repository),
          ),
          validateTransactionAllocationsServiceProvider.overrideWithValue(
            ValidateTransactionAllocationsService(
              getCategoryById: MockGetCategoryByIdUseCase(),
              getJarById: MockGetJarByIdUseCase(),
            ),
          ),
          validateTransactionTagsServiceProvider.overrideWithValue(
            ValidateTransactionTagsService(
              getTagsByIds: GetTagsByIdsUseCase(MockTagRepository()),
            ),
          ),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(updateTransactionServiceProvider);

      expect(service, isA<UpdateTransactionService>());
    });
  });
}
