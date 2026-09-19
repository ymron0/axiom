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
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/tag_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('tag service providers', () {
    test('resolve all tag services from feature-owned dependencies', () {
      // Given
      final tagRepository = MockTagRepository();
      final transactionRepository = MockTransactionRepository();

      final container = ProviderContainer(
        overrides: [
          tagRepositoryProvider.overrideWithValue(tagRepository),
          transactionRepositoryProvider.overrideWithValue(
            transactionRepository,
          ),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19, 12)),
          ),
        ],
      );

      addTearDown(container.dispose);

      // When
      final validateTransactionTags = container.read(
        validateTransactionTagsServiceProvider,
      );

      final assignTag = container.read(
        assignTagToTransactionServiceProvider,
      );

      final removeTag = container.read(
        removeTagFromTransactionServiceProvider,
      );

      final deleteTag = container.read(
        deleteTagServiceProvider,
      );

      final mergeTags = container.read(
        mergeTagsServiceProvider,
      );

      // Then
      expect(
        validateTransactionTags,
        isA<ValidateTransactionTagsService>(),
      );

      expect(
        assignTag,
        isA<AssignTagToTransactionService>(),
      );

      expect(
        removeTag,
        isA<RemoveTagFromTransactionService>(),
      );

      expect(
        deleteTag,
        isA<DeleteTagService>(),
      );

      expect(
        mergeTags,
        isA<MergeTagsService>(),
      );
    });
  });
}