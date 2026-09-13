import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/delete_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_in_use_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_merchant_id_use_case.dart';

/// Deletes a merchant when no persisted transaction references it.
///
/// This service coordinates the Merchants and Transactions features. It checks
/// transaction usage before delegating deletion to [DeleteMerchantUseCase].
///
/// ## Invariants
///
/// - A merchant referenced by a persisted transaction is not deleted.
/// - Merchant deletion is delegated to [DeleteMerchantUseCase].
/// - This service does not access feature repositories directly.
///
/// ## Contract
///
/// Returns:
///
/// - the deleted merchant snapshot on success;
/// - the failure returned while checking transaction usage;
/// - [MerchantInUseFailure] when a transaction references the merchant;
/// - the failure returned while deleting the merchant.
final class DeleteMerchantService {
  /// Creates a merchant deletion service.
  const DeleteMerchantService({
    required TransactionsExistByMerchantIdUseCase transactionsExist,
    required DeleteMerchantUseCase deleteMerchant,
  }) : _transactionsExist = // ignore: prefer_initializing_formals
           transactionsExist,
       _deleteMerchant = deleteMerchant; // ignore: prefer_initializing_formals

  final TransactionsExistByMerchantIdUseCase _transactionsExist;
  final DeleteMerchantUseCase _deleteMerchant;

  /// Deletes the merchant identified by [merchantId] when it is not in use.
  Future<Result<Merchant, BaseFailure>> call(MerchantId merchantId) async {
    final usageResult = await _transactionsExist(merchantId);

    return usageResult.when<Future<Result<Merchant, BaseFailure>>>(
      success: (exists) async {
        if (exists) {
          return MerchantInUseFailure(
            message: 'Merchant is referenced by a transaction: $merchantId',
          );
        }

        return _deleteMerchant(merchantId);
      },
      failure: (failure) async => failure,
    );
  }
}
