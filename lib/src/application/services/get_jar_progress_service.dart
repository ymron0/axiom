import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/jars/domain/services/jar_progress_calculator.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_progress.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Derives the current balance and target progress of one jar.
///
/// This service coordinates:
///
/// - Jars, to resolve the jar and its effective target;
/// - Settings, to resolve the valuation currency;
/// - Transactions, to obtain allocations referencing the jar; and
/// - domain calculators, to perform monetary arithmetic.
///
/// ## Current balance semantics
///
/// Only actual transactions effective at or before the current instant
/// participate in the current jar balance.
///
/// Planned transactions are intentionally excluded because they represent
/// forecast activity rather than actual financial activity.
///
/// ## Currency semantics
///
/// No exchange-rate lookup occurs here.
///
/// Transaction splits already contain their value in the application's
/// valuation currency through `TransactionSplit.valuationAmount`.
///
/// Re-converting those historical amounts would be incorrect because it could
/// revalue an old transaction using a different rate than the one associated
/// with the original transaction.
///
/// ## Contract
///
/// Returns:
///
/// - [JarProgress] when the jar can be resolved successfully;
/// - [JarNotFoundFailure] when no jar exists for the supplied ID;
/// - [SettingsNotInitializedFailure] when application settings do not exist;
/// - or failures propagated from the underlying feature use cases.
final class GetJarProgressService {
  final GetJarByIdUseCase _getJarById;
  final GetSettingsUseCase _getSettings;
  final GetTransactionsByJarIdUseCase _getTransactionsByJarId;
  final JarBalanceCalculator _balanceCalculator;
  final JarProgressCalculator _progressCalculator;
  final Clock _clock;

  /// Creates the cross-feature jar progress service.
  const GetJarProgressService({
    required GetJarByIdUseCase getJarById,
    required GetSettingsUseCase getSettings,
    required GetTransactionsByJarIdUseCase getTransactionsByJarId,
    required JarBalanceCalculator balanceCalculator,
    required JarProgressCalculator progressCalculator,
    required Clock clock,
  }) : _getJarById = getJarById, // ignore: prefer_initializing_formals
       _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getTransactionsByJarId = // ignore: prefer_initializing_formals
           getTransactionsByJarId,
       _balanceCalculator = // ignore: prefer_initializing_formals
           balanceCalculator,
       _progressCalculator = // ignore: prefer_initializing_formals
           progressCalculator,
       _clock = clock; // ignore: prefer_initializing_formals

  /// Derives the current balance and progress of [jarId].
  Future<Result<JarProgress, BaseFailure>> call(JarId jarId) async {
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

    final now = _clock.now;
    final nowUtc = now.toUtc();

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

    final progress = _progressCalculator.calculate(
      jar: jar,
      balance: balance,
      asOf: CalendarDate.fromDateTime(now),
    );

    return Success(progress);
  }
}
