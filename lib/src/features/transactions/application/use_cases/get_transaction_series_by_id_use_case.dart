import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Retrieves one transaction series by identity.
final class GetTransactionSeriesByIdUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const GetTransactionSeriesByIdUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Returns the series identified by [id].
  ///
  /// A successful `null` result means that no persisted series has the supplied
  /// identity.
  Future<Result<TransactionSeries?, TransactionSeriesFailure>> call(
    TransactionSeriesId id,
  ) {
    return _repository.getById(id);
  }
}
