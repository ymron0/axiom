import 'package:axiom/src/application/services/delete_jar_service.dart';
import 'package:axiom/src/features/jars/di/delete_jar_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_jar_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_jar_service_provider.g.dart';

/// Provides the service that deletes jars which have no transactions.
@riverpod
DeleteJarService deleteJarService(Ref ref) {
  return DeleteJarService(
    transactionsExistByJarId: ref.watch(
      transactionsExistByJarIdUseCaseProvider,
    ),
    deleteJar: ref.watch(deleteJarUseCaseProvider),
  );
}
