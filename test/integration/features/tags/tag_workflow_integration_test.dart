@Tags(['integration', 'tags', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/application/di/services/assign_tag_to_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/delete_tag_service_provider.dart';
import 'package:axiom/src/application/di/services/merge_tags_service_provider.dart';
import 'package:axiom/src/application/di/services/remove_tag_from_transaction_service_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/tags/di/archive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/create_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_name_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_tag_id_use_case_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('Tag workflow integration', () {
    late ProviderContainer container;
    late DatabaseLifecycleService lifecycleService;
    late Directory rootDirectory;

    final timestamp = DateTime.utc(2026, 9, 19, 12);

    setUp(() async {
      final rootPath = _uniqueRootPath();

      rootDirectory = Directory(rootPath);

      container = ProviderContainer(
        overrides: [
          databaseRootPathProvider.overrideWithValue(rootPath),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );

      lifecycleService = container.read(databaseLifecycleServiceProvider);

      final openResult = await lifecycleService.open();

      expect(openResult.isSuccess, isTrue);
    });

    tearDown(() async {
      await lifecycleService.close();

      container.dispose();

      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    test(
      'assigns, archives, preserves, removes, and safely deletes a tag',
      () async {
        // Given
        final createTag = container.read(createTagUseCaseProvider);

        final createResult = await createTag('  Business   Trip  ');

        expect(createResult.isSuccess, isTrue);

        final tag = createResult.valueOrNull!;

        expect(tag.name, 'Business Trip');

        final transactionRepository = container.read(
          transactionRepositoryProvider,
        );

        final taggedTransaction = transactionFixture(
          id: 'tag-lifecycle-tagged',
        );

        final untouchedTransaction = transactionFixture(
          id: 'tag-lifecycle-untouched',
        );

        expect(
          (await transactionRepository.create(taggedTransaction)).isSuccess,
          isTrue,
        );

        expect(
          (await transactionRepository.create(untouchedTransaction)).isSuccess,
          isTrue,
        );

        final assignTag = container.read(assignTagToTransactionServiceProvider);

        // When: assign the active tag.
        final assignmentResult = await assignTag(
          transactionId: taggedTransaction.id,
          tagId: tag.id,
        );

        // Then
        expect(assignmentResult.isSuccess, isTrue);

        var persistedTagged = (await transactionRepository.getById(
          taggedTransaction.id,
        )).valueOrNull!;

        expect(persistedTagged.tagIds, [tag.id]);

        // When: retire the tag.
        final archiveResult = await container.read(archiveTagUseCaseProvider)(
          tag.id,
        );

        // Then: historical reference remains valid.
        expect(archiveResult.isSuccess, isTrue);

        expect(archiveResult.valueOrNull!.isArchived, isTrue);

        persistedTagged = (await transactionRepository.getById(
          taggedTransaction.id,
        )).valueOrNull!;

        expect(persistedTagged.tagIds, [tag.id]);

        // But the archived tag cannot be newly assigned elsewhere.
        final rejectedAssignment = await assignTag(
          transactionId: untouchedTransaction.id,
          tagId: tag.id,
        );

        expect(
          rejectedAssignment.failureOrNull,
          isA<TagNotAssignableFailure>(),
        );

        final persistedUntouched = (await transactionRepository.getById(
          untouchedTransaction.id,
        )).valueOrNull!;

        expect(persistedUntouched.tagIds, isEmpty);

        // When: remove the historical reference.
        final removeResult = await container.read(
          removeTagFromTransactionServiceProvider,
        )(transactionId: taggedTransaction.id, tagId: tag.id);

        // Then
        expect(removeResult.isSuccess, isTrue);

        persistedTagged = (await transactionRepository.getById(
          taggedTransaction.id,
        )).valueOrNull!;

        expect(persistedTagged.tagIds, isEmpty);

        final existsResult = await container.read(
          transactionsExistByTagIdUseCaseProvider,
        )(tag.id);

        expect(existsResult.valueOrNull, isFalse);

        // When: no transaction references remain, deletion is safe.
        final deleteResult = await container.read(deleteTagServiceProvider)(
          tag.id,
        );

        // Then
        expect(deleteResult.isSuccess, isTrue);

        final persistedTagResult = await container
            .read(tagRepositoryProvider)
            .getById(tag.id);

        expect(persistedTagResult.isSuccess, isTrue);

        expect(persistedTagResult.valueOrNull, isNull);

        // Regression: unrelated transaction data remains unchanged.
        final finalUntouched = (await transactionRepository.getById(
          untouchedTransaction.id,
        )).valueOrNull!;

        expect(finalUntouched.tagIds, isEmpty);

        expect(
          finalUntouched.ledgerEntries,
          untouchedTransaction.ledgerEntries,
        );

        expect(finalUntouched.splits, untouchedTransaction.splits);
      },
    );

    test(
      'merges source tag references into the target and deletes the source',
      () async {
        // Given
        final createTag = container.read(createTagUseCaseProvider);

        final sourceResult = await createTag('Source');

        final targetResult = await createTag('Target');

        expect(sourceResult.isSuccess, isTrue);

        expect(targetResult.isSuccess, isTrue);

        final source = sourceResult.valueOrNull!;
        final target = targetResult.valueOrNull!;

        final transactionRepository = container.read(
          transactionRepositoryProvider,
        );

        final sourceOnly = transactionFixture(
          id: 'tag-merge-source-only',
          tagIds: [source.id],
        );

        final sourceAndTarget = transactionFixture(
          id: 'tag-merge-source-and-target',
          tagIds: [target.id, source.id],
        );

        final unrelated = transactionFixture(id: 'tag-merge-unrelated');

        expect(
          (await transactionRepository.create(sourceOnly)).isSuccess,
          isTrue,
        );

        expect(
          (await transactionRepository.create(sourceAndTarget)).isSuccess,
          isTrue,
        );

        expect(
          (await transactionRepository.create(unrelated)).isSuccess,
          isTrue,
        );

        final mergeTags = container.read(mergeTagsServiceProvider);

        // When
        final mergeResult = await mergeTags(
          sourceTagId: source.id,
          targetTagId: target.id,
        );

        // Then
        expect(mergeResult.isSuccess, isTrue);

        expect(mergeResult.valueOrNull!.id, target.id);

        final tagRepository = container.read(tagRepositoryProvider);

        final sourceAfterMerge = await tagRepository.getById(source.id);

        expect(sourceAfterMerge.isSuccess, isTrue);

        expect(sourceAfterMerge.valueOrNull, isNull);

        final targetAfterMerge = await tagRepository.getById(target.id);

        expect(targetAfterMerge.valueOrNull!.id, target.id);

        expect(targetAfterMerge.valueOrNull!.isArchived, isFalse);

        final persistedSourceOnly = (await transactionRepository.getById(
          sourceOnly.id,
        )).valueOrNull!;

        expect(persistedSourceOnly.tagIds, [target.id]);

        final persistedSourceAndTarget = (await transactionRepository.getById(
          sourceAndTarget.id,
        )).valueOrNull!;

        // Existing target is not duplicated.
        expect(persistedSourceAndTarget.tagIds, [target.id]);

        final persistedUnrelated = (await transactionRepository.getById(
          unrelated.id,
        )).valueOrNull!;

        expect(persistedUnrelated.tagIds, isEmpty);

        final remainingSourceReferences = await container.read(
          getTransactionsByTagIdUseCaseProvider,
        )(source.id);

        expect(remainingSourceReferences.valueOrNull, isEmpty);

        final targetReferences = await container.read(
          getTransactionsByTagIdUseCaseProvider,
        )(target.id);

        expect(targetReferences.valueOrNull, hasLength(2));

        final sourceStillExists = await container.read(
          transactionsExistByTagIdUseCaseProvider,
        )(source.id);

        expect(sourceStillExists.valueOrNull, isFalse);
      },
    );

    test(
      'enforces normalized tag-name uniqueness through the full stack',
      () async {
        // Given
        final createTag = container.read(createTagUseCaseProvider);

        // When
        final firstResult = await createTag('  Business   Trip  ');

        final duplicateResult = await createTag('business trip');

        // Then
        expect(firstResult.isSuccess, isTrue);

        expect(firstResult.valueOrNull!.name, 'Business Trip');

        expect(
          duplicateResult.failureOrNull,
          isA<TagNameAlreadyExistsFailure>(),
        );

        final allTagsResult = await container
            .read(tagRepositoryProvider)
            .getAll();

        expect(allTagsResult.isSuccess, isTrue);

        expect(allTagsResult.valueOrNull, hasLength(1));

        expect(
          allTagsResult.valueOrNull!.single.id,
          firstResult.valueOrNull!.id,
        );
      },
    );
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'tag-workflow-integration-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
