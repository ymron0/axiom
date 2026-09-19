import 'package:axiom/src/application/services/merge_tags_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/tags/di/archive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/delete_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tag_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'merge_tags_service_provider.g.dart';

/// Provides the cross-feature tag merge workflow.
@riverpod
MergeTagsService mergeTagsService(Ref ref) {
  return MergeTagsService(
    clock: ref.watch(clockProvider),
    getTagById: ref.watch(getTagByIdUseCaseProvider),
    archiveTag: ref.watch(archiveTagUseCaseProvider),
    getTransactionsByTagId: ref.watch(getTransactionsByTagIdUseCaseProvider),
    updateTransaction: ref.watch(updateTransactionUseCaseProvider),
    transactionsExistByTagId: ref.watch(
      transactionsExistByTagIdUseCaseProvider,
    ),
    deleteTag: ref.watch(deleteTagUseCaseProvider),
  );
}
