import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_in_use_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Deletes a tag only when no persisted transaction references it.
///
/// Archiving remains available when historical references must be retained.
final class DeleteTagService {
  final TransactionsExistByTagIdUseCase _transactionsExist;
  final DeleteTagUseCase _deleteTag;

  /// Creates a referentially safe tag deletion workflow.
  const DeleteTagService({
    required TransactionsExistByTagIdUseCase transactionsExist,
    required DeleteTagUseCase deleteTag,
  }) : _transactionsExist = // ignore: prefer_initializing_formals
           transactionsExist,
       _deleteTag = deleteTag; // ignore: prefer_initializing_formals

  /// Deletes [id] when it is unused.
  Future<Result<Tag, BaseFailure>> call(TagId id) async {
    final usageResult = await _transactionsExist(id);

    if (usageResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    if (usageResult.valueOrNull!) {
      return TagInUseFailure(
        message:
            'Tag cannot be deleted while transactions reference it: '
            '${id.value}',
      );
    }

    return _deleteTag(id);
  }
}
