import 'package:axiom/src/application/services/delete_tag_service.dart';
import 'package:axiom/src/features/tags/di/delete_tag_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_tag_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_tag_service_provider.g.dart';

/// Provides referentially safe tag deletion.
@riverpod
DeleteTagService deleteTagService(Ref ref) {
  return DeleteTagService(
    transactionsExist: ref.watch(transactionsExistByTagIdUseCaseProvider),
    deleteTag: ref.watch(deleteTagUseCaseProvider),
  );
}
