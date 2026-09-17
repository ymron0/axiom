import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Derives the current balance of one jar in the configured valuation currency.
///
/// This service coordinates the Jars, Settings, and Transactions features while
/// delegating monetary arithmetic to [JarBalanceCalculator].
///
/// ## Balance semantics
///
/// A jar balance is derived exclusively from transaction allocations targeting
/// that jar.
///
/// Only transactions that are:
///
/// - in [TransactionState.actual]; and
/// - financially effective at or before the current instant
///
/// participate in the balance.
///
/// Planned transactions are intentionally excluded because they describe
/// forecast activity rather than realized financial activity.
///
/// ## Asset semantics
///
/// Jar balances are expressed in the application's configured valuation
/// currency.
///
/// Each transaction split already stores its historical valuation through
/// `TransactionSplit.valuationAmount`. This service therefore does not perform
/// exchange-rate lookup or revaluation.
///
/// Revaluing a historical split would be incorrect because doing so could apply
/// a rate different from the one associated with the original transaction.
///
/// [JarBalanceCalculator] validates that every selected valuation amount uses
/// the currently configured valuation currency.
///
/// ## Direction semantics
///
/// Incoming allocations increase the jar balance.
///
/// Outgoing allocations decrease the jar balance.
///
/// A balance below zero is represented as an outgoing [AssetAmount] with a
/// positive magnitude.
///
/// An empty jar has an incoming zero balance in the configured valuation
/// currency.
///
/// ## Contract
///
/// Returns:
///
/// - the current jar balance on success;
/// - [JarNotFoundFailure] when [jarId] does not identify a persisted jar;
/// - [SettingsNotInitializedFailure] when application settings do not exist;
/// - or a failure propagated unchanged from an underlying use case.
///
/// Domain invariant and programmer errors are deliberately not translated into
/// failures. For example, persisted splits using an unexpected valuation asset
/// cause [JarBalanceCalculator] to throw [ArgumentError].
final class GetJarBalanceService {
  final GetJarByIdUseCase _getJarById;
  final GetSettingsUseCase _getSettings;
  final GetTransactionsByJarIdUseCase _getTransactionsByJarId;
  final JarBalanceCalculator _balanceCalculator;
  final Clock _clock;

  /// Creates the cross-feature jar balance service.
  const GetJarBalanceService({
    required GetJarByIdUseCase getJarById,
    required GetSettingsUseCase getSettings,
    required GetTransactionsByJarIdUseCase getTransactionsByJarId,
    required JarBalanceCalculator balanceCalculator,
    required Clock clock,
  }) : _getJarById = getJarById, // ignore: prefer_initializing_formals
       _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getTransactionsByJarId = // ignore: prefer_initializing_formals
           getTransactionsByJarId,
       _balanceCalculator = // ignore: prefer_initializing_formals
           balanceCalculator,
       _clock = clock; // ignore: prefer_initializing_formals

  /// Returns the current balance of [jarId].
  Future<Result<AssetAmount, BaseFailure>> call(JarId jarId) async {
    final jarResult = await _getJarById(jarId);

    if (jarResult case final Failure<JarFailure> failure) {
      return failure;
    }

    final jar = jarResult.valueOrNull;

    if (jar == null) {
      return JarNotFoundFailure(
        message: 'Jar ID was not found: ${jarId.value}',
      );
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

    final transactionsResult = await _getTransactionsByJarId(jar.id);

    if (transactionsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final nowUtc = _clock.nowUtc;
    final allocationAmounts = <AssetAmount>[];

    for (final transaction in transactionsResult.valueOrNull!) {
      if (transaction.state != TransactionState.actual) {
        continue;
      }

      if (transaction.effectiveAt.isAfter(nowUtc)) {
        continue;
      }

      for (final split in transaction.splits) {
        if (split.jarId != jar.id) {
          continue;
        }

        allocationAmounts.add(split.valuationAmount);
      }
    }

    final balance = _balanceCalculator.calculate(
      valuationCurrencyId: settings.valuationCurrencyId,
      allocationAmounts: allocationAmounts,
    );

    return Success(balance);
  }
}
