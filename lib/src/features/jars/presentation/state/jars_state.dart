import 'package:axiom/src/application/di/services/get_jar_progress_service_provider.dart';
import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/di/get_active_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_progress.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'jars_state.g.dart';

/// Supporting values required by create/edit jar forms.
final class JarFormOptions {
  /// Creates jar form options.
  const JarFormOptions({
    required this.valuationCurrency,
    required this.effectiveDate,
    required this.nextSortOrder,
  });

  final Currency valuationCurrency;
  final CalendarDate effectiveDate;
  final int nextSortOrder;
}

/// Presentation data required for rendering jar progress.
final class JarProgressPresentationData {
  /// Creates jar progress presentation data.
  const JarProgressPresentationData({
    required this.progress,
    required this.valuationCurrency,
  });

  final JarProgress progress;
  final Currency valuationCurrency;
}

/// One transaction allocation belonging to a jar.
///
/// Multiple splits on the same transaction targeting the same jar are
/// collapsed into one valuation-currency amount.
final class JarAllocationEntry {
  /// Creates a jar allocation entry.
  const JarAllocationEntry({required this.transaction, required this.amount});

  final Transaction transaction;
  final AssetAmount amount;
}

/// Allocation data together with its valuation currency.
final class JarAllocationPresentationData {
  /// Creates allocation presentation data.
  const JarAllocationPresentationData({
    required this.entries,
    required this.valuationCurrency,
  });

  final List<JarAllocationEntry> entries;
  final Currency valuationCurrency;
}

/// Loads active jars for the normal overview.
@riverpod
Future<Result<List<Jar>, JarFailure>> jars(Ref ref) async {
  final result = await ref.watch(getActiveJarsUseCaseProvider)();

  return result.when<Result<List<Jar>, JarFailure>>(
    success: (jars) => Success(_sortJars(jars)),
    failure: (failure) => failure,
  );
}

/// Loads all jars, including archived jars.
@riverpod
Future<Result<List<Jar>, JarFailure>> allJars(Ref ref) async {
  final result = await ref.watch(getJarsUseCaseProvider)();

  return result.when<Result<List<Jar>, JarFailure>>(
    success: (jars) => Success(_sortJars(jars)),
    failure: (failure) => failure,
  );
}

/// Loads one jar by identity.
@riverpod
Future<Result<Jar?, JarFailure>> jar(Ref ref, JarId jarId) {
  return ref.watch(getJarByIdUseCaseProvider)(jarId);
}

/// Loads the configured valuation currency used by jars.
@riverpod
Future<Result<Currency, BaseFailure>> jarValuationCurrency(Ref ref) {
  return ref.watch(getValuationCurrencyServiceProvider)();
}

/// Loads supporting data for jar create/edit forms.
@riverpod
Future<Result<JarFormOptions, BaseFailure>> jarFormOptions(Ref ref) async {
  final currencyResult = await ref.watch(getValuationCurrencyServiceProvider)();

  if (currencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final jarsResult = await ref.watch(getJarsUseCaseProvider)();

  if (jarsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  var nextSortOrder = 0;

  for (final jar in jarsResult.valueOrNull!) {
    if (jar.sortOrder >= nextSortOrder) {
      nextSortOrder = jar.sortOrder + 1;
    }
  }

  final clock = ref.watch(clockProvider);

  return Success(
    JarFormOptions(
      valuationCurrency: currencyResult.valueOrNull!,
      effectiveDate: CalendarDate.fromDateTime(clock.now),
      nextSortOrder: nextSortOrder,
    ),
  );
}

/// Loads current jar balance and target progress for presentation.
@riverpod
Future<Result<JarProgressPresentationData, BaseFailure>>
jarProgressPresentation(Ref ref, JarId jarId) async {
  final progressResult = await ref.watch(getJarProgressServiceProvider)(jarId);

  if (progressResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final currencyResult = await ref.watch(getValuationCurrencyServiceProvider)();

  if (currencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    JarProgressPresentationData(
      progress: progressResult.valueOrNull!,
      valuationCurrency: currencyResult.valueOrNull!,
    ),
  );
}

/// Loads all transactions containing an allocation to [jarId].
@riverpod
Future<Result<List<Transaction>, TransactionFailure>> jarTransactions(
  Ref ref,
  JarId jarId,
) async {
  final result = await ref.watch(getTransactionsByJarIdUseCaseProvider)(jarId);

  return result.when<Result<List<Transaction>, TransactionFailure>>(
    success: (transactions) {
      final sorted = List<Transaction>.of(transactions)
        ..sort((left, right) {
          return right.effectiveAt.compareTo(left.effectiveAt);
        });

      return Success(List.unmodifiable(sorted));
    },
    failure: (failure) => failure,
  );
}

/// Derives jar-specific allocation amounts from its transactions.
@riverpod
Future<Result<List<JarAllocationEntry>, TransactionFailure>> jarAllocations(
  Ref ref,
  JarId jarId,
) async {
  final transactionsResult = await ref.watch(
    jarTransactionsProvider(jarId).future,
  );

  if (transactionsResult case final Failure<TransactionFailure> failure) {
    return failure;
  }

  final entries = <JarAllocationEntry>[];

  for (final transaction in transactionsResult.valueOrNull!) {
    final matchingSplits = transaction.splits
        .where((split) => split.jarId == jarId)
        .toList(growable: false);

    if (matchingSplits.isEmpty) {
      continue;
    }

    var signedTotal = Decimal.zero;

    for (final split in matchingSplits) {
      final amount = split.valuationAmount;

      signedTotal += amount.isIncoming ? amount.amount : -amount.amount;
    }

    final assetId = matchingSplits.first.valuationAmount.assetId;

    final allocation = signedTotal < Decimal.zero
        ? AssetAmount.outgoing(assetId: assetId, amount: signedTotal.abs())
        : AssetAmount.incoming(assetId: assetId, amount: signedTotal);

    entries.add(
      JarAllocationEntry(transaction: transaction, amount: allocation),
    );
  }

  return Success(List.unmodifiable(entries));
}

/// Loads allocation entries together with valuation-currency metadata.
@riverpod
Future<Result<JarAllocationPresentationData, BaseFailure>>
jarAllocationPresentation(Ref ref, JarId jarId) async {
  final allocationsResult = await ref.watch(
    jarAllocationsProvider(jarId).future,
  );

  if (allocationsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final currencyResult = await ref.watch(getValuationCurrencyServiceProvider)();

  if (currencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    JarAllocationPresentationData(
      entries: allocationsResult.valueOrNull!,
      valuationCurrency: currencyResult.valueOrNull!,
    ),
  );
}

List<Jar> _sortJars(Iterable<Jar> jars) {
  final sorted = List<Jar>.of(jars)
    ..sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);

      if (order != 0) {
        return order;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

  return List.unmodifiable(sorted);
}
