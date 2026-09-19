import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/archive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_active_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_archived_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_merchant_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/unarchive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_series_use_case_providers.g.dart';

/// Provides transaction-series creation.
@riverpod
CreateTransactionSeriesUseCase createTransactionSeriesUseCase(Ref ref) {
  return CreateTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides retrieval of all persisted transaction series.
@riverpod
GetTransactionSeriesUseCase getTransactionSeriesUseCase(Ref ref) {
  return GetTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides retrieval of active transaction series.
@riverpod
GetActiveTransactionSeriesUseCase getActiveTransactionSeriesUseCase(Ref ref) {
  return GetActiveTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides retrieval of archived transaction series.
@riverpod
GetArchivedTransactionSeriesUseCase getArchivedTransactionSeriesUseCase(
  Ref ref,
) {
  return GetArchivedTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides transaction-series lookup by identity.
@riverpod
GetTransactionSeriesByIdUseCase getTransactionSeriesByIdUseCase(Ref ref) {
  return GetTransactionSeriesByIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides transaction-series updates.
@riverpod
UpdateTransactionSeriesUseCase updateTransactionSeriesUseCase(Ref ref) {
  return UpdateTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides transaction-series archival.
@riverpod
ArchiveTransactionSeriesUseCase archiveTransactionSeriesUseCase(Ref ref) {
  return ArchiveTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}

/// Provides transaction-series unarchival.
@riverpod
UnarchiveTransactionSeriesUseCase unarchiveTransactionSeriesUseCase(Ref ref) {
  return UnarchiveTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}

/// Provides physical transaction-series deletion.
@riverpod
DeleteTransactionSeriesUseCase deleteTransactionSeriesUseCase(Ref ref) {
  return DeleteTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides transaction-series restoration.
@riverpod
RestoreTransactionSeriesUseCase restoreTransactionSeriesUseCase(Ref ref) {
  return RestoreTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides account-reference checks against transaction series.
@riverpod
TransactionSeriesExistByAccountIdUseCase
transactionSeriesExistByAccountIdUseCase(Ref ref) {
  return TransactionSeriesExistByAccountIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides merchant-reference checks against transaction series.
@riverpod
TransactionSeriesExistByMerchantIdUseCase
transactionSeriesExistByMerchantIdUseCase(Ref ref) {
  return TransactionSeriesExistByMerchantIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides category-reference checks against transaction series.
@riverpod
TransactionSeriesExistByCategoryIdUseCase
transactionSeriesExistByCategoryIdUseCase(Ref ref) {
  return TransactionSeriesExistByCategoryIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

/// Provides jar-reference checks against transaction series.
@riverpod
TransactionSeriesExistByJarIdUseCase transactionSeriesExistByJarIdUseCase(
  Ref ref,
) {
  return TransactionSeriesExistByJarIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
