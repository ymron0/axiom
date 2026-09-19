import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_series_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_series_repository_provider.g.dart';

/// Provides the persistent transaction-series repository.
///
/// Database lifecycle and integrity validation must complete before this
/// provider is resolved.
@Riverpod(keepAlive: true)
TransactionSeriesRepository transactionSeriesRepository(Ref ref) {
  return SembastTransactionSeriesRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
