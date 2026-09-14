import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/use_cases/delete_jar_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_in_use_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Coordinates safe jar deletion across the Jars and Transactions features.
///
/// A jar may be archived regardless of historical transaction usage, but it
/// cannot be physically deleted while any persisted transaction references it.
final class DeleteJarService {
  final TransactionsExistByJarIdUseCase _transactionsExistByJarId;
  final DeleteJarUseCase _deleteJar;

  /// Creates the cross-feature deletion service.
  const DeleteJarService({
    required TransactionsExistByJarIdUseCase transactionsExistByJarId,
    required DeleteJarUseCase deleteJar,
  }) : _transactionsExistByJarId = // ignore: prefer_initializing_formals
           transactionsExistByJarId,
       _deleteJar = deleteJar; // ignore: prefer_initializing_formals

  /// Deletes [jarId] when no persisted transaction references it.
  ///
  /// Transaction-query failures are propagated unchanged.
  ///
  /// Returns [JarInUseFailure] when at least one transaction references the
  /// jar.
  Future<Result<Jar, BaseFailure>> call(JarId jarId) async {
    final usageResult = await _transactionsExistByJarId(jarId);

    if (usageResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    if (usageResult.valueOrNull!) {
      return JarInUseFailure(
        message:
            'Jar cannot be deleted while transactions reference it: '
            '${jarId.value}',
      );
    }

    return _deleteJar(jarId);
  }
}
