import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Captures one consistent daily balance-snapshot set.
///
/// This service coordinates Accounts, Custodians, Jars, Settings,
/// Transactions, Rates, and Balance Snapshots.
///
/// It deliberately contains no scheduling, timer, isolate, background-worker,
/// retry-policy, notification, or platform lifecycle behavior.
///
/// A scheduler may invoke this service, but scheduling is outside this
/// service's responsibility.
///
/// ## Consistency
///
/// One invocation uses:
///
/// - one [snapshotDate];
/// - one UTC [capturedAt] timestamp;
/// - one valuation instant;
/// - one Settings snapshot;
/// - one Account collection;
/// - one Custodian collection;
/// - one Jar collection; and
/// - one Transaction collection.
///
/// The complete financial state is therefore evaluated against one logical
/// source set rather than independently re-querying transactions for every
/// subject.
///
/// ## Snapshot date
///
/// [snapshotDate] represents the daily financial position being captured.
///
/// Transactions are included when they:
///
/// - are actual;
/// - are effective before the UTC start of the following calendar date; and
/// - are not effective after the capture instant.
///
/// The second condition gives historical captures an end-of-day boundary. The
/// third prevents an invocation made during the current day from including an
/// actual transaction whose effective instant is still in the future.
///
/// ## Valuation instant
///
/// Historical captures use the final representable microsecond before the next
/// UTC calendar date.
///
/// A capture of the current UTC date uses [capturedAt] when the day has not yet
/// finished.
///
/// Every required conversion within one invocation uses that same valuation
/// instant.
///
/// ## Account semantics
///
/// An account may hold multiple assets while having exactly one valuation
/// currency.
///
/// The existing Account model currently exposes that valuation currency through
/// `Account.denominationAssetId`.
///
/// Account asset balances are derived from the transaction amounts belonging
/// to ledger entries affecting the account.
///
/// Each asset is aggregated independently. Zero net positions are omitted.
///
/// The complete asset position is then valued into the account's configured
/// valuation currency at the common valuation instant.
///
/// ## Custodian semantics
///
/// A custodian snapshot is derived from the account snapshots produced during
/// the same invocation.
///
/// Its asset balances are the per-asset aggregation of all included accounts.
///
/// Each account's total valuation is converted into the application's base
/// valuation currency before the custodian total is calculated.
///
/// Consequently, custodians may contain accounts using different account
/// valuation currencies while the custodian itself is always valued in the
/// user's configured base valuation currency.
///
/// ## Jar semantics
///
/// Jar balances remain transaction-allocation-derived.
///
/// Transaction-split valuation amounts already preserve the historical value
/// assigned to the jar. They are therefore aggregated directly rather than
/// revalued using current rates.
///
/// ## Persistence
///
/// Every snapshot is fully calculated before any snapshot is persisted.
///
/// This prevents a calculation or rate failure from leaving a partially
/// calculated capture set.
///
/// Snapshots are then saved sequentially through
/// [BalanceSnapshotRepository.save].
///
/// Repository writes are idempotent by subject and date. If persistence fails
/// after some snapshots have been saved, a later invocation may safely retry
/// the entire date.
///
/// ## Failure semantics
///
/// Expected failures from Settings, Accounts, Custodians, Jars, Transactions,
/// Rates, or snapshot persistence are propagated unchanged.
///
/// Missing settings return [SettingsNotInitializedFailure].
///
/// Unknown actual transaction amounts and other violated financial invariants
/// represent invalid persisted/domain state and therefore throw
/// [ArgumentError] rather than being translated into recoverable failures.
final class CaptureBalanceSnapshotsService {
  final GetSettingsUseCase _getSettings;
  final GetAccountsUseCase _getAccounts;
  final GetCustodiansUseCase _getCustodians;
  final GetJarsUseCase _getJars;
  final GetAllTransactionsUseCase _getTransactions;
  final ResolveConversionRateService _resolveConversionRate;
  final AssetValuationCalculator _assetValuationCalculator;
  final JarBalanceCalculator _jarBalanceCalculator;
  final BalanceSnapshotRepository _snapshotRepository;
  final Clock _clock;

  /// Creates the snapshot capture service.
  const CaptureBalanceSnapshotsService({
    required GetSettingsUseCase getSettings,
    required GetAccountsUseCase getAccounts,
    required GetCustodiansUseCase getCustodians,
    required GetJarsUseCase getJars,
    required GetAllTransactionsUseCase getTransactions,
    required ResolveConversionRateService resolveConversionRate,
    required AssetValuationCalculator assetValuationCalculator,
    required JarBalanceCalculator jarBalanceCalculator,
    required BalanceSnapshotRepository snapshotRepository,
    required Clock clock,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getAccounts = getAccounts, // ignore: prefer_initializing_formals
       _getCustodians = getCustodians, // ignore: prefer_initializing_formals
       _getJars = getJars, // ignore: prefer_initializing_formals
       _getTransactions = // ignore: prefer_initializing_formals
           getTransactions,
       _resolveConversionRate = // ignore: prefer_initializing_formals
           resolveConversionRate,
       _assetValuationCalculator = // ignore: prefer_initializing_formals
           assetValuationCalculator,
       _jarBalanceCalculator = // ignore: prefer_initializing_formals
           jarBalanceCalculator,
       _snapshotRepository = // ignore: prefer_initializing_formals
           snapshotRepository,
       _clock = clock; // ignore: prefer_initializing_formals

  /// Captures every account, custodian, and jar snapshot for [snapshotDate].
  ///
  /// Returns the snapshots in persistence order:
  ///
  /// 1. accounts;
  /// 2. custodians;
  /// 3. jars.
  ///
  /// The returned collection is immutable.
  Future<Result<List<BalanceSnapshot>, BaseFailure>> call(
    CalendarDate snapshotDate,
  ) async {
    final capturedAt = _clock.nowUtc;
    final snapshotStartUtc = snapshotDate.toDateTimeUtc();

    if (capturedAt.isBefore(snapshotStartUtc)) {
      throw ArgumentError.value(
        snapshotDate,
        'snapshotDate',
        'Cannot capture a balance snapshot for a future calendar date.',
      );
    }

    final snapshotUntilUtc = snapshotStartUtc.add(const Duration(days: 1));

    final valuationAt = capturedAt.isBefore(snapshotUntilUtc)
        ? capturedAt
        : snapshotUntilUtc.subtract(const Duration(microseconds: 1));

    final settingsResult = await _getSettings();

    if (settingsResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final settings = settingsResult.valueOrNull;

    if (settings == null) {
      return const SettingsNotInitializedFailure(
        message: 'Settings have not been initialized.',
      );
    }

    final accountsResult = await _getAccounts();

    if (accountsResult case final Failure<AccountFailure> failure) {
      return failure;
    }

    final custodiansResult = await _getCustodians();

    if (custodiansResult case final Failure<CustodianFailure> failure) {
      return failure;
    }

    final jarsResult = await _getJars();

    if (jarsResult case final Failure<JarFailure> failure) {
      return failure;
    }

    final transactionsResult = await _getTransactions();

    if (transactionsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final accounts = accountsResult.valueOrNull!
        .where(
          (account) => _entityExistedAt(
            createdAt: account.createdAt,
            snapshotUntilUtc: snapshotUntilUtc,
            capturedAt: capturedAt,
          ),
        )
        .toList(growable: false);

    final custodians = custodiansResult.valueOrNull!
        .where(
          (custodian) => _entityExistedAt(
            createdAt: custodian.createdAt,
            snapshotUntilUtc: snapshotUntilUtc,
            capturedAt: capturedAt,
          ),
        )
        .toList(growable: false);

    final jars = jarsResult.valueOrNull!
        .where(
          (jar) => _entityExistedAt(
            createdAt: jar.createdAt,
            snapshotUntilUtc: snapshotUntilUtc,
            capturedAt: capturedAt,
          ),
        )
        .toList(growable: false);

    final transactions = transactionsResult.valueOrNull!
        .where(
          (transaction) => _transactionApplies(
            transaction: transaction,
            snapshotUntilUtc: snapshotUntilUtc,
            capturedAt: capturedAt,
          ),
        )
        .toList(growable: false);

    final snapshots = <BalanceSnapshot>[];
    final accountSnapshots = <AccountId, BalanceSnapshot>{};

    for (final account in accounts) {
      final result = await _captureAccount(
        account: account,
        transactions: transactions,
        baseValuationCurrencyId: settings.valuationCurrencyId,
        snapshotDate: snapshotDate,
        capturedAt: capturedAt,
        valuationAt: valuationAt,
      );

      if (result case final Failure<BaseFailure> failure) {
        return failure;
      }

      final snapshot = result.valueOrNull!;
      snapshots.add(snapshot);
      accountSnapshots[account.id] = snapshot;
    }

    for (final custodian in custodians) {
      final result = captureCustodianSnapshot(
        custodian: custodian,
        accounts: accounts,
        accountSnapshots: accountSnapshots,
        baseValuationCurrencyId: settings.valuationCurrencyId,
        snapshotDate: snapshotDate,
        capturedAt: capturedAt,
      );

      snapshots.add(result);
    }

    for (final jar in jars) {
      final snapshot = _captureJar(
        jar: jar,
        transactions: transactions,
        baseValuationCurrencyId: settings.valuationCurrencyId,
        snapshotDate: snapshotDate,
        capturedAt: capturedAt,
      );

      snapshots.add(snapshot);
    }

    for (final snapshot in snapshots) {
      final saveResult = await _snapshotRepository.save(snapshot);

      if (saveResult case final Failure failure) {
        return failure;
      }
    }

    return Success(List.unmodifiable(snapshots));
  }

  /// Captures a custodian snapshot from its already-captured account snapshots.
  ///
  /// This member is exposed for direct invariant coverage. The normal capture
  /// workflow calls it only after producing an account snapshot for every
  /// included account.
  @visibleForTesting
  BalanceSnapshot captureCustodianSnapshot({
    required Custodian custodian,
    required List<Account> accounts,
    required Map<AccountId, BalanceSnapshot> accountSnapshots,
    required AssetId baseValuationCurrencyId,
    required CalendarDate snapshotDate,
    required DateTime capturedAt,
  }) {
    final assetAmounts = <AssetAmount>[];
    var signedValuation = Decimal.zero;

    for (final account in accounts) {
      if (account.custodianId != custodian.id) {
        continue;
      }

      final snapshot = accountSnapshots[account.id];

      if (snapshot == null) {
        throw StateError(
          'Account snapshot missing during custodian snapshot capture: '
          '${account.id.value}.',
        );
      }

      assetAmounts.addAll(snapshot.assetBalances);

      if (snapshot.valuationAmount.assetId != baseValuationCurrencyId) {
        throw StateError(
          'Account snapshot valuation does not use the configured base '
          'valuation currency: ${account.id.value}.',
        );
      }

      signedValuation += _toSignedAmount(snapshot.valuationAmount);
    }

    final assetBalances = _aggregateAssetAmounts(assetAmounts);

    final valuationAmount = _fromSignedAmount(
      assetId: baseValuationCurrencyId,
      signedAmount: signedValuation,
    );

    return BalanceSnapshot(
      subject: BalanceSnapshotSubject.custodian(custodian.id),
      snapshotDate: snapshotDate,
      capturedAt: capturedAt,
      assetBalances: assetBalances,
      denominationAmount: valuationAmount,
      valuationAmount: valuationAmount,
    );
  }

  /// Values [amounts] in [valuationCurrencyId] at [at].
  ///
  /// This member is exposed for direct invariant coverage. Snapshot balance
  /// aggregation normally rejects unknown amounts before this operation.
  @visibleForTesting
  Future<Result<AssetAmount, BaseFailure>> valueAmounts({
    required Iterable<AssetAmount> amounts,
    required AssetId valuationCurrencyId,
    required DateTime at,
  }) async {
    var signedTotal = Decimal.zero;

    for (final amount in amounts) {
      if (amount.isUnknownAmount) {
        throw ArgumentError.value(
          amount,
          'amounts',
          'Snapshot valuation cannot contain an unknown amount.',
        );
      }

      final valuationResult = await _valueAmount(
        amount: amount,
        valuationCurrencyId: valuationCurrencyId,
        at: at,
      );

      if (valuationResult case final Failure<BaseFailure> failure) {
        return failure;
      }

      signedTotal += _toSignedAmount(valuationResult.valueOrNull!);
    }

    return Success(
      _fromSignedAmount(
        assetId: valuationCurrencyId,
        signedAmount: signedTotal,
      ),
    );
  }

  List<AssetAmount> _aggregateAssetAmounts(Iterable<AssetAmount> amounts) {
    final balances = <AssetId, Decimal>{};

    for (final amount in amounts) {
      if (amount.isUnknownAmount) {
        throw ArgumentError.value(
          amount,
          'amounts',
          'Snapshot asset balances cannot contain unknown amounts.',
        );
      }

      balances.update(
        amount.assetId,
        (current) => current + _toSignedAmount(amount),
        ifAbsent: () => _toSignedAmount(amount),
      );
    }

    final result = <AssetAmount>[];

    for (final entry in balances.entries) {
      if (entry.value == Decimal.zero) {
        continue;
      }

      result.add(
        _fromSignedAmount(assetId: entry.key, signedAmount: entry.value),
      );
    }

    result.sort(
      (left, right) => left.assetId.value.compareTo(right.assetId.value),
    );

    return List.unmodifiable(result);
  }

  Future<Result<BalanceSnapshot, BaseFailure>> _captureAccount({
    required Account account,
    required List<Transaction> transactions,
    required AssetId baseValuationCurrencyId,
    required CalendarDate snapshotDate,
    required DateTime capturedAt,
    required DateTime valuationAt,
  }) async {
    final amounts = <AssetAmount>[];

    for (final transaction in transactions) {
      for (final entry in transaction.ledgerEntries) {
        if (entry.accountId != account.id) {
          continue;
        }

        amounts.add(entry.transactionAmount);
      }
    }

    final assetBalances = _aggregateAssetAmounts(amounts);

    final denominationResult = await valueAmounts(
      amounts: assetBalances,
      valuationCurrencyId: account.denominationAssetId,
      at: valuationAt,
    );

    if (denominationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationResult = await valueAmounts(
      amounts: assetBalances,
      valuationCurrencyId: baseValuationCurrencyId,
      at: valuationAt,
    );

    if (valuationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return Success(
      BalanceSnapshot(
        subject: BalanceSnapshotSubject.account(account.id),
        snapshotDate: snapshotDate,
        capturedAt: capturedAt,
        assetBalances: assetBalances,
        denominationAmount: denominationResult.valueOrNull!,
        valuationAmount: valuationResult.valueOrNull!,
      ),
    );
  }

  BalanceSnapshot _captureJar({
    required Jar jar,
    required List<Transaction> transactions,
    required AssetId baseValuationCurrencyId,
    required CalendarDate snapshotDate,
    required DateTime capturedAt,
  }) {
    final allocationAmounts = <AssetAmount>[];

    for (final transaction in transactions) {
      for (final split in transaction.splits) {
        if (split.jarId != jar.id) {
          continue;
        }

        allocationAmounts.add(split.valuationAmount);
      }
    }

    final balance = _jarBalanceCalculator.calculate(
      valuationCurrencyId: baseValuationCurrencyId,
      allocationAmounts: allocationAmounts,
    );

    return BalanceSnapshot(
      subject: BalanceSnapshotSubject.jar(jar.id),
      snapshotDate: snapshotDate,
      capturedAt: capturedAt,
      assetBalances: [balance],
      denominationAmount: balance,
      valuationAmount: balance,
    );
  }

  bool _entityExistedAt({
    required DateTime createdAt,
    required DateTime snapshotUntilUtc,
    required DateTime capturedAt,
  }) {
    if (!createdAt.isBefore(snapshotUntilUtc)) {
      return false;
    }

    if (createdAt.isAfter(capturedAt)) {
      return false;
    }

    return true;
  }

  AssetAmount _fromSignedAmount({
    required AssetId assetId,
    required Decimal signedAmount,
  }) {
    if (signedAmount < Decimal.zero) {
      return AssetAmount.outgoing(assetId: assetId, amount: signedAmount.abs());
    }

    return AssetAmount.incoming(assetId: assetId, amount: signedAmount);
  }

  Decimal _toSignedAmount(AssetAmount amount) {
    return amount.isIncoming ? amount.amount : -amount.amount;
  }

  bool _transactionApplies({
    required Transaction transaction,
    required DateTime snapshotUntilUtc,
    required DateTime capturedAt,
  }) {
    if (transaction.state != TransactionState.actual) {
      return false;
    }

    if (!transaction.effectiveAt.isBefore(snapshotUntilUtc)) {
      return false;
    }

    if (transaction.effectiveAt.isAfter(capturedAt)) {
      return false;
    }

    return true;
  }

  Future<Result<AssetAmount, BaseFailure>> _valueAmount({
    required AssetAmount amount,
    required AssetId valuationCurrencyId,
    required DateTime at,
  }) async {
    if (amount.assetId == valuationCurrencyId ||
        amount.amount == Decimal.zero) {
      return Success(
        _assetValuationCalculator.calculate(
          amount: amount,
          valuationCurrencyId: valuationCurrencyId,
        ),
      );
    }

    final rateResult = await _resolveConversionRate(
      fromAssetId: amount.assetId,
      toAssetId: valuationCurrencyId,
      at: at,
    );

    if (rateResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return Success(
      _assetValuationCalculator.calculate(
        amount: amount,
        valuationCurrencyId: valuationCurrencyId,
        conversionRate: rateResult.valueOrNull!,
      ),
    );
  }
}
