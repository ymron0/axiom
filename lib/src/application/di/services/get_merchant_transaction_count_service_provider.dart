import 'package:axiom/src/application/services/get_merchant_transaction_count_service.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_merchant_transaction_count_service_provider.g.dart';

/// Provides the service that counts a merchant's transactions during a period.
@riverpod
GetMerchantTransactionCountService getMerchantTransactionCountService(Ref ref) {
  return GetMerchantTransactionCountService(
    queryTransactions: ref.watch(queryTransactionsUseCaseProvider),
  );
}
