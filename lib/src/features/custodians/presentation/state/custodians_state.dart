import 'package:axiom/src/application/di/services/get_custodian_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/account_watch_queries_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/custodians/di/custodian_watch_queries_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/custodian_aggregation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'custodians_state.g.dart';

/// Complete data needed to display a custodian valuation.
final class CustodianValuationPresentationData {
  /// Creates presentation data.
  const CustodianValuationPresentationData({
    required this.aggregation,
    required this.valuationCurrency,
  });

  final CustodianAggregation aggregation;
  final Currency valuationCurrency;
}

/// Watches active custodians.
@riverpod
Stream<Result<List<Custodian>, CustodianFailure>> custodians(Ref ref) {
  return ref.watch(custodianWatchQueriesProvider).active().map((result) {
    return result.when<Result<List<Custodian>, CustodianFailure>>(
      success: (custodians) => Success(_sortCustodians(custodians)),
      failure: (failure) => failure,
    );
  });
}

/// Watches one custodian.
@riverpod
Stream<Result<Custodian?, CustodianFailure>> custodian(
  Ref ref,
  CustodianId custodianId,
) {
  return ref.watch(custodianWatchQueriesProvider).byId(custodianId);
}

/// Watches accounts belonging to one custodian.
@riverpod
Stream<Result<List<Account>, AccountFailure>> custodianAccounts(
  Ref ref,
  CustodianId custodianId,
) {
  return ref
      .watch(accountWatchQueriesProvider)
      .byCustodianId(custodianId)
      .map((result) {
        return result.when<Result<List<Account>, AccountFailure>>(
          success: (accounts) => Success(_sortAccounts(accounts)),
          failure: (failure) => failure,
        );
      });
}

/// Resolves deterministic custodian valuation presentation data.
@riverpod
Future<Result<CustodianValuationPresentationData, BaseFailure>>
custodianValuation(Ref ref, CustodianId custodianId) async {
  final aggregationResult = await ref.watch(
    getCustodianValuationServiceProvider,
  )(custodianId);

  if (aggregationResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final currencyResult = await ref.watch(getValuationCurrencyServiceProvider)();

  if (currencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    CustodianValuationPresentationData(
      aggregation: aggregationResult.valueOrNull!,
      valuationCurrency: currencyResult.valueOrNull!,
    ),
  );
}

/// Computes the default ordering position from the watched custodian list.
@riverpod
AsyncValue<Result<int, CustodianFailure>> nextCustodianSortOrder(Ref ref) {
  final source = ref.watch(custodiansProvider);

  return source.whenData((result) {
    return result.when<Result<int, CustodianFailure>>(
      success: (custodians) {
        var next = 0;

        for (final custodian in custodians) {
          if (custodian.sortOrder >= next) {
            next = custodian.sortOrder + 1;
          }
        }

        return Success(next);
      },
      failure: (failure) => failure,
    );
  });
}

List<Custodian> _sortCustodians(Iterable<Custodian> custodians) {
  final sorted = List<Custodian>.of(custodians)
    ..sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);

      if (order != 0) {
        return order;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

  return List.unmodifiable(sorted);
}

List<Account> _sortAccounts(Iterable<Account> accounts) {
  final sorted = List<Account>.of(accounts)
    ..sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);

      if (order != 0) {
        return order;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

  return List.unmodifiable(sorted);
}