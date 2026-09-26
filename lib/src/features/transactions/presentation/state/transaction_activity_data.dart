import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/presentation/state/transactions_view_state.dart';
import 'package:decimal/decimal.dart';

/// Unfiltered repository-backed data for one calendar month.
final class TransactionMonthSource {
  final DateTime monthStart;
  final List<Transaction> transactions;
  final List<Merchant> merchants;
  final List<Account> accounts;
  final List<Asset> assets;
  final List<Category> categories;
  final List<Jar> jars;
  final List<Tag> tags;
  final Currency valuationCurrency;

  final Map<MerchantId, Merchant> merchantsById;
  final Map<AccountId, Account> accountsById;
  final Map<AssetId, Asset> assetsById;
  final Map<CategoryId, Category> categoriesById;
  final Map<JarId, Jar> jarsById;
  final Map<TagId, Tag> tagsById;

  /// Creates monthly source data and identity lookups.
  TransactionMonthSource({
    required DateTime monthStart,
    required List<Transaction> transactions,
    required List<Merchant> merchants,
    required List<Account> accounts,
    required List<Asset> assets,
    required List<Category> categories,
    required List<Jar> jars,
    required List<Tag> tags,
    required this.valuationCurrency,
  }) : monthStart = DateTime(monthStart.year, monthStart.month),
       transactions = List.unmodifiable(transactions),
       merchants = List.unmodifiable(merchants),
       accounts = List.unmodifiable(accounts),
       assets = List.unmodifiable(assets),
       categories = List.unmodifiable(categories),
       jars = List.unmodifiable(jars),
       tags = List.unmodifiable(tags),
       merchantsById = Map.unmodifiable({
         for (final merchant in merchants) merchant.id: merchant,
       }),
       accountsById = Map.unmodifiable({
         for (final account in accounts) account.id: account,
       }),
       assetsById = Map.unmodifiable({
         for (final asset in assets) asset.id: asset,
       }),
       categoriesById = Map.unmodifiable({
         for (final category in categories) category.id: category,
       }),
       jarsById = Map.unmodifiable({for (final jar in jars) jar.id: jar}),
       tagsById = Map.unmodifiable({for (final tag in tags) tag.id: tag});
}

/// Income/expense summary for the selected transaction set.
final class TransactionSummary {
  final AssetId valuationAssetId;
  final Decimal income;
  final Decimal expense;
  final Decimal net;
  final int includedTransactionCount;
  final bool hasIncompleteValues;

  /// Creates a summary.
  const TransactionSummary({
    required this.valuationAssetId,
    required this.income,
    required this.expense,
    required this.net,
    required this.includedTransactionCount,
    required this.hasIncompleteValues,
  });

  /// Calculates income, expense and net flow.
  ///
  /// Transfers, balance corrections and trades are not treated as income or
  /// expense.
  ///
  /// Offsets reverse the financial classification of their original economic
  /// flow:
  ///
  /// - an income-shaped offset of an expense reduces expense;
  /// - an expense-shaped offset of income reduces income.
  factory TransactionSummary.calculate({
    required Iterable<Transaction> transactions,
    required AssetId valuationAssetId,
  }) {
    var income = Decimal.zero;
    var expense = Decimal.zero;
    var included = 0;
    var incomplete = false;

    for (final transaction in transactions) {
      final flowKind = transaction.kind;

      final isIncomeFlow =
          flowKind == TransactionKind.income ||
          flowKind == TransactionKind.dividend ||
          flowKind == TransactionKind.reward;

      final isExpenseFlow = flowKind == TransactionKind.expense;

      if (!isIncomeFlow && !isExpenseFlow) {
        continue;
      }

      final primaryEntries = transaction.ledgerEntries
          .where((entry) => entry.role == LedgerEntryRole.primary)
          .toList(growable: false);

      if (primaryEntries.length != 1) {
        incomplete = true;
        continue;
      }

      final amount = primaryEntries.single.valuationAmount;

      if (amount.assetId != valuationAssetId || amount.isUnknownAmount) {
        incomplete = true;
        continue;
      }

      included++;

      if (transaction.isOffset) {
        if (flowKind == TransactionKind.income) {
          expense -= amount.amount;
        } else if (flowKind == TransactionKind.expense) {
          income -= amount.amount;
        } else {
          income += amount.amount;
        }

        continue;
      }

      if (isIncomeFlow) {
        income += amount.amount;
      } else {
        expense += amount.amount;
      }
    }

    return TransactionSummary(
      valuationAssetId: valuationAssetId,
      income: income,
      expense: expense,
      net: income - expense,
      includedTransactionCount: included,
      hasIncompleteValues: incomplete,
    );
  }
}

/// Fully derived presentation data for the selected month.
final class TransactionActivityData {
  final TransactionMonthSource source;
  final DateTime now;
  final List<Transaction> transactions;
  final List<Transaction> upcomingTransactions;
  final TransactionSummary summary;

  /// Creates derived transaction presentation data.
  TransactionActivityData({
    required this.source,
    required this.now,
    required List<Transaction> transactions,
    required List<Transaction> upcomingTransactions,
    required this.summary,
  }) : transactions = List.unmodifiable(transactions),
       upcomingTransactions = List.unmodifiable(upcomingTransactions);

  /// Builds local search/filter/sort/projected state without re-querying storage.
  factory TransactionActivityData.fromSource({
    required TransactionMonthSource source,
    required TransactionsViewState viewState,
    required DateTime now,
  }) {
    final matching = source.transactions
        .where((transaction) {
          return _matchesFilters(
                transaction: transaction,
                filters: viewState.filters,
              ) &&
              _matchesSearch(
                transaction: transaction,
                query: viewState.searchQuery,
                source: source,
              );
        })
        .toList(growable: false);

    final main = matching.where((transaction) {
      if (viewState.viewMode == TransactionViewMode.actual &&
          transaction.state != TransactionState.actual) {
        return false;
      }

      final isFuturePlanned =
          transaction.state == TransactionState.planned &&
          transaction.effectiveAt.isAfter(now.toUtc());

      return !isFuturePlanned;
    }).toList();

    _sortTransactions(main, order: viewState.sortOrder, source: source);

    final upcoming =
        matching
            .where(
              (transaction) =>
                  transaction.state == TransactionState.planned &&
                  transaction.effectiveAt.isAfter(now.toUtc()),
            )
            .toList()
          ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));

    final summaryTransactions = viewState.viewMode == TransactionViewMode.actual
        ? matching.where(
            (transaction) => transaction.state == TransactionState.actual,
          )
        : matching;

    return TransactionActivityData(
      source: source,
      now: now,
      transactions: main,
      upcomingTransactions: upcoming,
      summary: TransactionSummary.calculate(
        transactions: summaryTransactions,
        valuationAssetId: source.valuationCurrency.id,
      ),
    );
  }

  static bool _matchesFilters({
    required Transaction transaction,
    required TransactionFilters filters,
  }) {
    if (filters.kinds.isNotEmpty && !filters.kinds.contains(transaction.kind)) {
      return false;
    }

    if (filters.states.isNotEmpty &&
        !filters.states.contains(transaction.state)) {
      return false;
    }

    if (filters.accountIds.isNotEmpty &&
        !transaction.ledgerEntries.any(
          (entry) => filters.accountIds.contains(entry.accountId),
        )) {
      return false;
    }

    if (filters.tagIds.isNotEmpty &&
        !transaction.tagIds.any(filters.tagIds.contains)) {
      return false;
    }

    return true;
  }

  static bool _matchesSearch({
    required Transaction transaction,
    required String query,
    required TransactionMonthSource source,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return true;
    }

    final merchant = transaction.merchantId.isSelf
        ? ''
        : source.merchantsById[transaction.merchantId]?.name ?? '';

    final accountNames = transaction.ledgerEntries
        .map((entry) => source.accountsById[entry.accountId]?.name ?? '')
        .join(' ');

    final tagNames = transaction.tagIds
        .map((id) => source.tagsById[id]?.name ?? '')
        .join(' ');

    final text = [
      merchant,
      transaction.description ?? '',
      transaction.note ?? '',
      _kindText(transaction.kind),
      accountNames,
      tagNames,
    ].join(' ').toLowerCase();

    return text.contains(normalizedQuery);
  }

  static void _sortTransactions(
    List<Transaction> transactions, {
    required TransactionSortOrder order,
    required TransactionMonthSource source,
  }) {
    transactions.sort((a, b) {
      return switch (order) {
        TransactionSortOrder.newest => b.effectiveAt.compareTo(a.effectiveAt),
        TransactionSortOrder.oldest => a.effectiveAt.compareTo(b.effectiveAt),
        TransactionSortOrder.merchant => _merchantText(
          a,
          source,
        ).compareTo(_merchantText(b, source)),
        TransactionSortOrder.valueDescending => _valuationMagnitude(
          b,
        ).compareTo(_valuationMagnitude(a)),
      };
    });
  }

  static String _merchantText(
    Transaction transaction,
    TransactionMonthSource source,
  ) {
    if (transaction.merchantId.isSelf) {
      return _kindText(transaction.kind).toLowerCase();
    }

    return (source.merchantsById[transaction.merchantId]?.name ?? '')
        .toLowerCase();
  }

  static Decimal _valuationMagnitude(Transaction transaction) {
    var total = Decimal.zero;

    for (final entry in transaction.ledgerEntries) {
      if (entry.role != LedgerEntryRole.primary ||
          entry.valuationAmount.isUnknownAmount) {
        continue;
      }

      total += entry.valuationAmount.amount;
    }

    return total;
  }

  static String _kindText(TransactionKind kind) {
    return switch (kind) {
      TransactionKind.expense => 'expense',
      TransactionKind.income => 'income',
      TransactionKind.transfer => 'transfer',
      TransactionKind.balanceCorrection => 'balance correction',
      TransactionKind.buy => 'buy',
      TransactionKind.sell => 'sell',
      TransactionKind.dividend => 'dividend',
      TransactionKind.reward => 'reward',
    };
  }
}
