import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/rate_already_exists_failure.dart';
import 'package:axiom/src/core/failures/rate_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:fixtures/fixtures.dart';

/// Stores rate observations in memory, initially populated from [ratesFixtures].
///
/// This implementation follows the complete [RateRepository] contract without
/// providing persistence or live rate acquisition.
final class InMemoryRateRepositoryImpl implements RateRepository {
  final List<Rate> _rates = ratesFixtures
      .map<Rate>(
        (fixture) => ExchangeRate(
          id: RateId.fromString(fixture.id),
          baseAssetId: AssetId.fromString(fixture.baseAssetId),
          quoteAssetId: AssetId.fromString(fixture.quoteAssetId),
          rate: Decimal.parse(fixture.rate.toString()),
          effectiveAt: fixture.effectiveAt,
          entityVersion: fixture.entityVersion,
          createdAt: fixture.createdAt,
          modifiedAt: fixture.modifiedAt,
        ),
      )
      .toList();

  @override
  Future<Result<void, BaseFailure>> create(Rate rate) async {
    if (_rates.any((storedRate) => storedRate.id == rate.id)) {
      return RateAlreadyExistsFailure(
        message: 'Rate ID already exists: ${rate.id.value}',
      );
    }

    _rates.add(rate);
    return const Success(null);
  }

  @override
  Future<Result<void, BaseFailure>> createAll(List<Rate> rates) async {
    final requestedIds = <String>{};
    for (final rate in rates) {
      if (!requestedIds.add(rate.id.value)) {
        return RateAlreadyExistsFailure(
          message: 'Rate ID is duplicated: ${rate.id.value}',
        );
      }
    }

    if (_rates.any((rate) => requestedIds.contains(rate.id.value))) {
      final duplicate = _rates.firstWhere(
        (rate) => requestedIds.contains(rate.id.value),
      );
      return RateAlreadyExistsFailure(
        message: 'Rate ID already exists: ${duplicate.id.value}',
      );
    }

    _rates.addAll(rates);
    return const Success(null);
  }

  @override
  Future<Result<Rate, BaseFailure>> getById(RateId id) async {
    for (final rate in _rates) {
      if (rate.id == id) {
        return Success(rate);
      }
    }

    return RateNotFoundFailure(message: 'Rate ID was not found: ${id.value}');
  }

  @override
  Future<Result<BatchLookup<Rate, RateId>, BaseFailure>> getByIds(
    List<RateId> ids,
  ) async {
    final requestedIds = <String>{};
    final requested = <RateId>[];
    for (final id in ids) {
      if (requestedIds.add(id.value)) {
        requested.add(id);
      }
    }

    final found = _rates
        .where((rate) => requestedIds.contains(rate.id.value))
        .toList();
    final foundIds = found.map((rate) => rate.id.value).toSet();
    final missing = requested
        .where((id) => !foundIds.contains(id.value))
        .toList();

    return Success(BatchLookup(found: found, missing: missing));
  }

  @override
  Future<Result<List<Rate>, BaseFailure>> getByPair({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) async {
    final matchingRates =
        _rates
            .where(
              (rate) =>
                  rate.baseAssetId == baseAssetId &&
                  rate.quoteAssetId == quoteAssetId,
            )
            .toList()
          ..sort(
            (first, second) => first.effectiveAt.compareTo(second.effectiveAt),
          );

    return Success(List.unmodifiable(matchingRates));
  }

  @override
  Future<Result<Rate, BaseFailure>> getLatestByPair({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) async {
    final matchingRates = (await getByPair(
      baseAssetId: baseAssetId,
      quoteAssetId: quoteAssetId,
    )).valueOrNull;
    if (matchingRates == null || matchingRates.isEmpty) {
      return RateNotFoundFailure(
        message: 'No rate was found for the requested asset pair.',
      );
    }

    return Success(matchingRates.last);
  }

  @override
  Future<Result<Rate, BaseFailure>> getAtOrBefore({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required DateTime effectiveAt,
  }) async {
    final matchingRates = (await getByPair(
      baseAssetId: baseAssetId,
      quoteAssetId: quoteAssetId,
    )).valueOrNull;
    final eligibleRates = matchingRates
        ?.where((rate) => !rate.effectiveAt.isAfter(effectiveAt.toUtc()))
        .toList();

    if (eligibleRates == null || eligibleRates.isEmpty) {
      return RateNotFoundFailure(
        message: 'No rate was found at or before the requested instant.',
      );
    }

    return Success(eligibleRates.last);
  }
}
