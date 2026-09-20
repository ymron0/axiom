import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodian_by_id_use_case.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/services/custodian_aggregation_calculator.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/custodian_aggregation.dart';

/// Values every account belonging to one custodian and aggregates the results.
///
/// Individual account balances may use arbitrary supported Asset types.
///
/// Every [AccountValuation.valuationAmount] and the resulting
/// [CustodianAggregation.total] use the configured fiat valuation Currency.
final class GetCustodianValuationService {
  final GetCustodianByIdUseCase _getCustodianById;

  final GetAccountsByCustodianIdUseCase _getAccountsByCustodianId;
  final GetAccountValuationService _getAccountValuation;
  final GetValuationCurrencyService _getValuationCurrency;
  final CustodianAggregationCalculator _calculator;
  /// Creates the custodian valuation workflow.
  const GetCustodianValuationService({
    required GetCustodianByIdUseCase getCustodianById,
    required GetAccountsByCustodianIdUseCase getAccountsByCustodianId,
    required GetAccountValuationService getAccountValuation,
    required GetValuationCurrencyService getValuationCurrency,
    required CustodianAggregationCalculator calculator,
  }) : _getCustodianById = // ignore: prefer_initializing_formals
           getCustodianById,
       _getAccountsByCustodianId = // ignore: prefer_initializing_formals
           getAccountsByCustodianId,
       _getAccountValuation = // ignore: prefer_initializing_formals
           getAccountValuation,
       _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency,
       _calculator = calculator; // ignore: prefer_initializing_formals

  /// Returns the current valuation of [custodianId].
  Future<Result<CustodianAggregation, BaseFailure>> call(
    CustodianId custodianId,
  ) async {
    final custodianResult = await _getCustodianById(custodianId);

    if (custodianResult case final Failure<CustodianFailure> failure) {
      return failure;
    }

    final custodian = custodianResult.valueOrNull;

    if (custodian == null) {
      return CustodianNotFoundFailure(
        message: 'Custodian ID was not found: ${custodianId.value}',
      );
    }

    final accountsResult = await _getAccountsByCustodianId(custodian.id);

    if (accountsResult case final Failure<AccountFailure> failure) {
      return failure;
    }

    final currencyResult = await _getValuationCurrency();

    if (currencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationCurrency = currencyResult.valueOrNull!;
    final accountValuations = <AccountValuation>[];

    for (final account in accountsResult.valueOrNull!) {
      final valuationResult = await _getAccountValuation(account.id);

      if (valuationResult case final Failure<BaseFailure> failure) {
        return failure;
      }

      accountValuations.add(valuationResult.valueOrNull!);
    }

    return Success(
      _calculator.calculate(
        custodianId: custodian.id,
        valuationCurrencyId: valuationCurrency.id,
        accountValuations: accountValuations,
      ),
    );
  }
}
