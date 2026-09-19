@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/assign_tag_to_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/delete_tag_service_provider.dart';
import 'package:axiom/src/application/di/services/merge_tags_service_provider.dart';
import 'package:axiom/src/application/di/services/remove_tag_from_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_tags_service_provider.dart';
import 'package:axiom/src/application/services/assign_tag_to_transaction_service.dart';
import 'package:axiom/src/application/services/delete_tag_service.dart';
import 'package:axiom/src/application/services/merge_tags_service.dart';
import 'package:axiom/src/application/services/remove_tag_from_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/tags/application/use_cases/archive_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_id_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/di/archive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/delete_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tag_by_id_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tags_by_ids_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/tag_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('tag application service providers', () {
    test('provide all tag application services', () {
      final tagRepository = MockTagRepository();
      final transactionRepository = MockTransactionRepository();
      final timestamp = DateTime.utc(2026, 9, 19);

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(timestamp)),
          getTagsByIdsUseCaseProvider.overrideWithValue(
            GetTagsByIdsUseCase(tagRepository),
          ),
          getTagByIdUseCaseProvider.overrideWithValue(
            GetTagByIdUseCase(tagRepository),
          ),
          archiveTagUseCaseProvider.overrideWithValue(
            ArchiveTagUseCase(
              repository: tagRepository,
              clock: FixedClock(timestamp),
            ),
          ),
          deleteTagUseCaseProvider.overrideWithValue(
            DeleteTagUseCase(tagRepository),
          ),
          getTransactionByIdUseCaseProvider.overrideWithValue(
            GetTransactionByIdUseCase(transactionRepository),
          ),
          getTransactionsByTagIdUseCaseProvider.overrideWithValue(
            GetTransactionsByTagIdUseCase(transactionRepository),
          ),
          transactionsExistByTagIdUseCaseProvider.overrideWithValue(
            TransactionsExistByTagIdUseCase(transactionRepository),
          ),
          updateTransactionUseCaseProvider.overrideWithValue(
            UpdateTransactionUseCase(transactionRepository),
          ),
        ],
      );

      addTearDown(container.dispose);

      expect(
        container.read(validateTransactionTagsServiceProvider),
        isA<ValidateTransactionTagsService>(),
      );

      expect(
        container.read(assignTagToTransactionServiceProvider),
        isA<AssignTagToTransactionService>(),
      );

      expect(
        container.read(removeTagFromTransactionServiceProvider),
        isA<RemoveTagFromTransactionService>(),
      );

      expect(container.read(deleteTagServiceProvider), isA<DeleteTagService>());

      expect(container.read(mergeTagsServiceProvider), isA<MergeTagsService>());
    });
  });
}
