import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Determines whether persisted transaction series reference a category.
///
/// References contained in recurrence-exception replacement templates are
/// included.
final class TransactionSeriesExistByCategoryIdUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const TransactionSeriesExistByCategoryIdUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Whether at least one persisted series references [categoryId].
  Future<Result<bool, TransactionSeriesFailure>> call(CategoryId categoryId) {
    return _repository.existsByCategoryId(categoryId);
  }
}
