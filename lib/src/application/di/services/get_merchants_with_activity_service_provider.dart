import 'package:axiom/src/application/services/get_merchants_with_activity_service.dart';
import 'package:axiom/src/features/merchants/di/get_merchants_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_merchants_with_activity_service_provider.g.dart';

/// Provides the service that resolves merchants with activity during a period.
@riverpod
GetMerchantsWithActivityService getMerchantsWithActivityService(Ref ref) {
  return GetMerchantsWithActivityService(
    queryTransactions: ref.watch(queryTransactionsUseCaseProvider),
    getMerchants: ref.watch(getMerchantsUseCaseProvider),
  );
}
