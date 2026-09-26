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
import 'package:axiom/src/features/transactions/di/transaction_watch_queries_provider.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:axiom/src/features/transactions/presentation/providers/transactions_view_controller.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_month_source_provider.g.dart';

/// Watches transaction data for one month.
///
/// The transaction collection itself is reactive. Supporting reference data is
/// reloaded whenever the watched transaction stream emits.
///
/// The period uses local-calendar boundaries converted to UTC.
@riverpod
Stream<Result<TransactionMonthSource, BaseFailure>> transactionMonthSource(
  Ref ref,
  DateTime month,
) async* {
  final transactionQueries = ref.watch(transactionWatchQueriesProvider);

  final getMerchants = ref.watch(getMerchantsUseCaseProvider);
  final getArchivedMerchants = ref.watch(getArchivedMerchantsUseCaseProvider);
  final getAccounts = ref.watch(getAccountsUseCaseProvider);
  final getArchivedAccounts = ref.watch(getArchivedAccountsUseCaseProvider);
  final getAssets = ref.watch(getAssetUseCaseProvider);
  final getCategories = ref.watch(getCategoriesUseCaseProvider);
  final getJars = ref.watch(getJarsUseCaseProvider);
  final getTags = ref.watch(getTagsUseCaseProvider);
  final getValuationCurrency = ref.watch(getValuationCurrencyServiceProvider);

  final monthStart = DateTime(month.year, month.month);
  final monthEnd = DateTime(month.year, month.month + 1);

  final transactions = transactionQueries.query(
    TransactionQuery(
      effectiveFrom: monthStart.toUtc(),
      effectiveUntil: monthEnd.toUtc(),
    ),
  );

  await for (final transactionsResult in transactions) {
    if (transactionsResult case final Failure<TransactionFailure> failure) {
      yield failure;
      continue;
    }

    final merchantsResult = await getMerchants();

    if (merchantsResult case final Failure<MerchantFailure> failure) {
      yield failure;
      continue;
    }

    final archivedMerchantsResult = await getArchivedMerchants();

    if (archivedMerchantsResult case final Failure<MerchantFailure> failure) {
      yield failure;
      continue;
    }

    final accountsResult = await getAccounts();

    if (accountsResult case final Failure<AccountFailure> failure) {
      yield failure;
      continue;
    }

    final archivedAccountsResult = await getArchivedAccounts();

    if (archivedAccountsResult case final Failure<AccountFailure> failure) {
      yield failure;
      continue;
    }

    final assetsResult = await getAssets();

    if (assetsResult case final Failure<AssetFailure> failure) {
      yield failure;
      continue;
    }

    final categoriesResult = await getCategories();

    if (categoriesResult case final Failure<CategoryFailure> failure) {
      yield failure;
      continue;
    }

    final jarsResult = await getJars();

    if (jarsResult case final Failure<JarFailure> failure) {
      yield failure;
      continue;
    }

    final tagsResult = await getTags();

    if (tagsResult case final Failure<TagFailure> failure) {
      yield failure;
      continue;
    }

    final valuationCurrencyResult = await getValuationCurrency();

    if (valuationCurrencyResult case final Failure<BaseFailure> failure) {
      yield failure;
      continue;
    }

    yield Success(
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
}

/// Applies local view state to the watched monthly repository result.
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
