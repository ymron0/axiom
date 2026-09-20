import 'package:axiom/src/application/failures/transaction_would_make_jar_balance_negative_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:decimal/decimal.dart';

/// Validates whether a transaction is permitted by the configured jar-balance
/// enforcement policy.
///
/// ## Configuration
///
/// Jar-balance enforcement is controlled by
/// `Settings.allowNegativeJarBalances`.
///
/// When it is `true`, this service succeeds without loading existing jar
/// transactions.
///
/// When it is `false`, actual transaction allocations are checked against the
/// chronological balance history of every affected jar.
///
/// ## Planned transactions
///
/// Planned transactions do not affect actual jar balances.
///
/// An update from actual to planned is still validated because removing the
/// previous actual allocation can reduce a jar's balance.
///
/// An update from planned to actual is validated because the replacement begins
/// contributing to actual jar balances.
///
/// ## Chronology
///
/// Validation operates on transaction effective instants rather than only the
/// current balance.
///
/// This means a backdated transaction cannot be accepted when it would create a
/// negative balance at its effective instant or at a later transaction instant.
///
/// Transactions sharing the same effective instant are treated as one balance
/// change. Their persistence ordering therefore does not affect validation.
///
/// ## Existing negative balances
///
/// Strict enforcement does not make historical negative data uneditable.
///
/// A transaction is rejected only when the projected balance:
///
/// 1. is negative; and
/// 2. is lower than the currently persisted balance at the same effective
///    instant.
///
/// Consequently, an already-negative jar may be improved while remaining
/// negative, but it cannot be made more negative.
///
/// ## Updates
///
/// When [previous] is supplied, the existing persisted transaction is removed
/// from the projected history before [transaction] is applied.
///
/// This correctly handles changes to:
///
/// - amount;
/// - direction;
/// - state;
/// - effective time; and
/// - jar allocation.
class ValidateTransactionJarBalancesService {
  final GetSettingsUseCase _getSettings;
  final GetTransactionsByJarIdUseCase _getTransactionsByJarId;
  final JarBalanceCalculator _calculator;

  /// Creates the jar-balance validator.
  const ValidateTransactionJarBalancesService({
    required GetSettingsUseCase getSettings,
    required GetTransactionsByJarIdUseCase getTransactionsByJarId,
    required JarBalanceCalculator calculator,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getTransactionsByJarId = // ignore: prefer_initializing_formals
           getTransactionsByJarId,
       _calculator = calculator; // ignore: prefer_initializing_formals

  /// Validates [transaction].
  ///
  /// Supply [previous] when [transaction] replaces an already persisted
  /// transaction.
  Future<Result<void, BaseFailure>> call(
    Transaction transaction, {
    Transaction? previous,
  }) async {
    if (previous != null && previous.id != transaction.id) {
      throw ArgumentError.value(
        previous.id,
        'previous',
        'Previous and replacement transactions must have the same identity.',
      );
    }

    final affectedJarIds = _affectedJarIds(
      transaction: transaction,
      previous: previous,
    );

    if (affectedJarIds.isEmpty) {
      return const Success(null);
    }

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

    if (settings.allowNegativeJarBalances) {
      return const Success(null);
    }

    for (final jarId in affectedJarIds) {
      final transactionsResult = await _getTransactionsByJarId(jarId);

      if (transactionsResult case final Failure<TransactionFailure> failure) {
        return failure;
      }

      final currentTransactions = transactionsResult.valueOrNull!;

      final projectedTransactions = <Transaction>[
        for (final existing in currentTransactions)
          if (previous == null || existing.id != previous.id) existing,
        if (_contributesToJar(transaction, jarId)) transaction,
      ];

      final failure = _validateJarTimeline(
        jarId: jarId,
        valuationCurrencyId: settings.valuationCurrencyId,
        currentTransactions: currentTransactions,
        projectedTransactions: projectedTransactions,
      );

      if (failure != null) {
        return failure;
      }
    }

    return const Success(null);
  }

  Set<JarId> _affectedJarIds({
    required Transaction transaction,
    required Transaction? previous,
  }) {
    final ids = <JarId>{};

    if (previous?.state == TransactionState.actual) {
      for (final split in previous!.splits) {
        if (split.jarId != null) {
          ids.add(split.jarId!);
        }
      }
    }

    if (transaction.state == TransactionState.actual) {
      for (final split in transaction.splits) {
        if (split.jarId != null) {
          ids.add(split.jarId!);
        }
      }
    }

    return ids;
  }

  bool _contributesToJar(Transaction transaction, JarId jarId) {
    if (transaction.state != TransactionState.actual) {
      return false;
    }

    return transaction.splits.any((split) => split.jarId == jarId);
  }

  TransactionWouldMakeJarBalanceNegativeFailure? _validateJarTimeline({
    required JarId jarId,
    required AssetId valuationCurrencyId,
    required Iterable<Transaction> currentTransactions,
    required Iterable<Transaction> projectedTransactions,
  }) {
    final currentDeltas = _deltasByInstant(
      jarId: jarId,
      valuationCurrencyId: valuationCurrencyId,
      transactions: currentTransactions,
    );

    final projectedDeltas = _deltasByInstant(
      jarId: jarId,
      valuationCurrencyId: valuationCurrencyId,
      transactions: projectedTransactions,
    );

    final instants = <DateTime>{
      ...currentDeltas.keys,
      ...projectedDeltas.keys,
    }.toList()..sort();

    var currentBalance = Decimal.zero;
    var projectedBalance = Decimal.zero;

    for (final instant in instants) {
      currentBalance += currentDeltas[instant] ?? Decimal.zero;
      projectedBalance += projectedDeltas[instant] ?? Decimal.zero;

      final isNegative = projectedBalance < Decimal.zero;
      final worsensBalance = projectedBalance < currentBalance;

      if (isNegative && worsensBalance) {
        return TransactionWouldMakeJarBalanceNegativeFailure(
          message:
              'Transaction would make the balance of jar '
              '"${jarId.value}" negative or more negative. '
              'Effective instant: ${instant.toIso8601String()}. '
              'Current balance: $currentBalance. '
              'Projected balance: $projectedBalance. '
              'Valuation asset: ${valuationCurrencyId.value}.',
        );
      }
    }

    return null;
  }

  Map<DateTime, Decimal> _deltasByInstant({
    required JarId jarId,
    required AssetId valuationCurrencyId,
    required Iterable<Transaction> transactions,
  }) {
    final deltas = <DateTime, Decimal>{};

    for (final transaction in transactions) {
      if (transaction.state != TransactionState.actual) {
        continue;
      }

      final allocationAmounts = <AssetAmount>[
        for (final split in transaction.splits)
          if (split.jarId == jarId) split.valuationAmount,
      ];

      if (allocationAmounts.isEmpty) {
        continue;
      }

      final amount = _calculator.calculate(
        valuationCurrencyId: valuationCurrencyId,
        allocationAmounts: allocationAmounts,
      );

      final signedAmount = amount.isIncoming ? amount.amount : -amount.amount;

      final instant = transaction.effectiveAt.toUtc();

      deltas[instant] = (deltas[instant] ?? Decimal.zero) + signedAmount;
    }

    return deltas;
  }
}
