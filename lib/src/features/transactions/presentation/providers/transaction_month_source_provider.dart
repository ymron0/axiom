import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/di/get_archived_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/merchants/di/get_archived_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/di/get_merchants_use_case_provider.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/tags/di/get_tags_use_case_provider.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/presentation/providers/transactions_view_controller.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_month_source_provider.g.dart';

/// Loads repository-backed transaction and reference data for one month.
///
/// The period uses local-calendar boundaries converted to UTC, so a transaction
/// belongs to the month the user sees rather than to an arbitrary UTC month.
@riverpod
Future<Result<TransactionMonthSource, BaseFailure>> transactionMonthSource(
  Ref ref,
  DateTime month,
) async {
  final monthStart = DateTime(month.year, month.month);
  final monthEnd = DateTime(month.year, month.month + 1);

  final transactionsResult = await ref
      .watch(queryTransactionsUseCaseProvider)
      .call(
        TransactionQuery(
          effectiveFrom: monthStart.toUtc(),
          effectiveUntil: monthEnd.toUtc(),
        ),
      );

  if (transactionsResult case final Failure<TransactionFailure> failure) {
    return failure;
  }

  final merchantsResult = await ref.watch(getMerchantsUseCaseProvider).call();

  if (merchantsResult case final Failure<MerchantFailure> failure) {
    return failure;
  }

  final archivedMerchantsResult = await ref
      .watch(getArchivedMerchantsUseCaseProvider)
      .call();

  if (archivedMerchantsResult case final Failure<MerchantFailure> failure) {
    return failure;
  }

  final accountsResult = await ref.watch(getAccountsUseCaseProvider).call();

  if (accountsResult case final Failure<AccountFailure> failure) {
    return failure;
  }

  final archivedAccountsResult = await ref
      .watch(getArchivedAccountsUseCaseProvider)
      .call();

  if (archivedAccountsResult case final Failure<AccountFailure> failure) {
    return failure;
  }

  final assetsResult = await ref.watch(getAssetUseCaseProvider).call();

  if (assetsResult case final Failure<AssetFailure> failure) {
    return failure;
  }

  final categoriesResult = await ref.watch(getCategoriesUseCaseProvider).call();

  if (categoriesResult case final Failure<CategoryFailure> failure) {
    return failure;
  }

  final jarsResult = await ref.watch(getJarsUseCaseProvider).call();

  if (jarsResult case final Failure<JarFailure> failure) {
    return failure;
  }

  final tagsResult = await ref.watch(getTagsUseCaseProvider).call();

  if (tagsResult case final Failure<TagFailure> failure) {
    return failure;
  }

  final valuationCurrencyResult = await ref
      .watch(getValuationCurrencyServiceProvider)
      .call();

  if (valuationCurrencyResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    TransactionMonthSource(
      monthStart: monthStart,
      transactions: transactionsResult.valueOrNull!,
      merchants: [
        ...merchantsResult.valueOrNull!,
        ...archivedMerchantsResult.valueOrNull!,
      ],
      accounts: [
        ...accountsResult.valueOrNull!,
        ...archivedAccountsResult.valueOrNull!,
      ],
      assets: assetsResult.valueOrNull!,
      categories: categoriesResult.valueOrNull!,
      jars: jarsResult.valueOrNull!,
      tags: tagsResult.valueOrNull!,
      valuationCurrency: valuationCurrencyResult.valueOrNull!,
    ),
  );
}

/// Applies local view state to the cached monthly repository result.
@riverpod
AsyncValue<Result<TransactionActivityData, BaseFailure>>
transactionActivityData(Ref ref) {
  final viewState = ref.watch(transactionsViewControllerProvider);

  final source = ref.watch(
    transactionMonthSourceProvider(viewState.monthStart),
  );

  final now = ref.watch(clockProvider).now;

  return source.whenData(
    (result) => result.when<Result<TransactionActivityData, BaseFailure>>(
      success: (value) {
        return Success(
          TransactionActivityData.fromSource(
            source: value,
            viewState: viewState,
            now: now,
          ),
        );
      },
      failure: (failure) => failure,
    ),
  );
}
