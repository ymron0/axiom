import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';

/// Validates that every category budget uses the configured valuation Currency.
///
/// A CategoryBudget stores only an Asset ID and therefore cannot prove by
/// itself that the ID represents the configured fiat valuation currency.
final class ValidateCategoryBudgetCurrenciesService {
  final GetValuationCurrencyService _getValuationCurrency;

  /// Creates the validator.
  const ValidateCategoryBudgetCurrenciesService({
    required GetValuationCurrencyService getValuationCurrency,
  }) : _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency;

  /// Validates [budgets].
  ///
  /// An empty collection succeeds without requiring initialized Settings.
  Future<Result<void, BaseFailure>> call(
    Iterable<CategoryBudget> budgets,
  ) async {
    if (budgets.isEmpty) {
      return const Success(null);
    }

    final currencyResult = await _getValuationCurrency();

    if (currencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationCurrency = currencyResult.valueOrNull!;

    for (final budget in budgets) {
      if (budget.limit.assetId != valuationCurrency.id) {
        return InvalidValuationCurrencyFailure(
          message:
              'Category budget currency '
              '${budget.limit.assetId.value} must match valuation currency '
              '${valuationCurrency.id.value}.',
        );
      }
    }

    return const Success(null);
  }
}