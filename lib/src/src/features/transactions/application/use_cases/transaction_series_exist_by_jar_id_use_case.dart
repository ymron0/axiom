import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';

/// Determines whether persisted transaction series reference a jar.
///
/// Active and archived series both count as references.
final class TransactionSeriesExistByJarIdUseCase {
  final TransactionSeriesRepository _repository;

  /// Creates a use case backed by [repository].
  const TransactionSeriesExistByJarIdUseCase({
    required TransactionSeriesRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  /// Whether at least one persisted series references [jarId].
  Future<Result<bool, TransactionSeriesFailure>> call(JarId jarId) {
    return _repository.existsByJarId(jarId);
  }
}
