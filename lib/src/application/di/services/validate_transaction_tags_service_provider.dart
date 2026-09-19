import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/features/tags/di/get_tags_by_ids_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_transaction_tags_service_provider.g.dart';

/// Provides transaction tag-reference validation.
@riverpod
ValidateTransactionTagsService validateTransactionTagsService(Ref ref) {
  return ValidateTransactionTagsService(
    getTagsByIds: ref.watch(getTagsByIdsUseCaseProvider),
  );
}
