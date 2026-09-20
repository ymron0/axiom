import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Returns assets that may be used as payment assets.
///
/// This deliberately differs from "all assets".
///
/// A non-payment-enabled asset may still legitimately denominate an account.
/// For example, a brokerage account may be denominated in a StockAsset even
/// though that stock cannot be selected as the payment asset for an expense.
final class GetPaymentAssetsUseCase {
  final AssetRepository _repository;

  /// Creates the query use case.
  const GetPaymentAssetsUseCase(this._repository);

  /// Returns every persisted asset whose domain semantics permit payments.
  Future<Result<List<Asset>, AssetFailure>> call() async {
    final result = await _repository.getAll();

    return result.when<Result<List<Asset>, AssetFailure>>(
      success: (assets) => Success(
        List.unmodifiable(assets.where((asset) => asset.paymentEnabled)),
      ),
      failure: (failure) => failure,
    );
  }
}
