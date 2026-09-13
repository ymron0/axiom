import 'package:axiom/src/application/services/delete_merchant_service.dart';
import 'package:axiom/src/features/merchants/di/delete_merchant_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_merchant_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_merchant_service_provider.g.dart';

/// Provides the service that deletes merchants which have no transactions.
@riverpod
DeleteMerchantService deleteMerchantService(Ref ref) {
  return DeleteMerchantService(
    transactionsExist: ref.watch(
      transactionsExistByMerchantIdUseCaseProvider,
    ),
    deleteMerchant: ref.watch(deleteMerchantUseCaseProvider),
  );
}
