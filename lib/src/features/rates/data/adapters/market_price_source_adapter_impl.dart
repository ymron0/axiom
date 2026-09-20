import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/failures/rate_source_acquisition_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/ports/market_price_source_adapter.dart';
import 'package:axiom/src/features/rates/data/data_sources/market_price_data_source.dart';

/// Adapts market-price data-source results to the application Rates API.
///
/// This adapter rejects currency base assets, delegates acquisition to the
/// market-price data source, maps successful observations to the application
/// model, and translates source failures into [RateSourceAcquisitionFailure].
final class MarketPriceSourceAdapterImpl implements MarketPriceSourceAdapter {
  final MarketPriceDataSource _dataSource;

  /// Creates the adapter.
  const MarketPriceSourceAdapterImpl({
    required MarketPriceDataSource dataSource,
  }) : _dataSource = dataSource; // ignore: prefer_initializing_formals

  @override
  Future<Result<RateSourceObservation, BaseFailure>> fetchLatest({
    required Asset baseAsset,
    required Currency quoteCurrency,
  }) async {
    if (baseAsset is Currency) {
      throw ArgumentError.value(
        baseAsset,
        'baseAsset',
        'Currency assets must use the exchange-rate source.',
      );
    }

    final result = await _dataSource.getLatest(
      baseAssetCode: baseAsset.code,
      quoteAssetCode: quoteCurrency.code,
    );

    return result.when<Result<RateSourceObservation, BaseFailure>>(
      success: (observation) => Success(
        RateSourceObservation(
          rate: observation.price,
          effectiveAt: observation.effectiveAt,
        ),
      ),
      failure: (failure) => RateSourceAcquisitionFailure(
        message:
            failure.message ??
            'Market-price source failed with ${failure.type}.',
      ),
    );
  }
}
