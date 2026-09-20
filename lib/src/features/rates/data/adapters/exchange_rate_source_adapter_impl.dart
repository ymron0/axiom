import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/failures/rate_source_acquisition_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/ports/exchange_rate_source_adapter.dart';
import 'package:axiom/src/features/rates/data/data_sources/exchange_rate_data_source.dart';
import 'package:axiom/src/features/rates/data/exceptions/exchange_rate_data_source_exception.dart';

/// Adapts an [ExchangeRateDataSource] to the application Rates boundary.
///
/// It requests one observation for the requested currency pair, verifies that
/// the source returned exactly that pair, and translates source exceptions or
/// malformed responses into [RateSourceAcquisitionFailure].
final class ExchangeRateSourceAdapterImpl implements ExchangeRateSourceAdapter {
  final ExchangeRateDataSource _dataSource;

  /// Creates the adapter.
  const ExchangeRateSourceAdapterImpl({
    required ExchangeRateDataSource dataSource,
  }) : _dataSource = dataSource; // ignore: prefer_initializing_formals

  @override
  Future<Result<RateSourceObservation, BaseFailure>> fetchLatest({
    required Currency baseCurrency,
    required Currency quoteCurrency,
  }) async {
    try {
      final observations = await _dataSource.fetchLatest(
        quoteCurrency: quoteCurrency,
        baseCurrencies: [baseCurrency],
      );

      if (observations.length != 1) {
        return RateSourceAcquisitionFailure(
          message:
              'Expected exactly one exchange-rate observation for '
              '${baseCurrency.code.value}/${quoteCurrency.code.value}, '
              'but received ${observations.length}.',
        );
      }

      final observation = observations.single;

      if (observation.baseAssetId != baseCurrency.id ||
          observation.quoteAssetId != quoteCurrency.id) {
        return RateSourceAcquisitionFailure(
          message:
              'Exchange-rate source returned an unexpected asset pair for '
              '${baseCurrency.code.value}/${quoteCurrency.code.value}.',
        );
      }

      return Success(
        RateSourceObservation(
          rate: observation.rate,
          effectiveAt: observation.effectiveAt,
        ),
      );
    } on ExchangeRateDataSourceException catch (error) {
      return RateSourceAcquisitionFailure(message: error.message);
    }
  }
}
