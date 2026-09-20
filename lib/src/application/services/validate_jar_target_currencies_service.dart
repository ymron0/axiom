import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';

/// Validates that Jar targets use the configured fiat valuation Currency.
final class ValidateJarTargetCurrenciesService {
  final GetValuationCurrencyService _getValuationCurrency;

  /// Creates the validator.
  const ValidateJarTargetCurrenciesService({
    required GetValuationCurrencyService getValuationCurrency,
  }) : _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency;

  /// Validates all [targets].
  ///
  /// Empty targets are valid without requiring initialized Settings.
  Future<Result<void, BaseFailure>> call(Iterable<JarTarget> targets) async {
    if (targets.isEmpty) {
      return const Success(null);
    }

    final currencyResult = await _getValuationCurrency();

    if (currencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationCurrency = currencyResult.valueOrNull!;

    for (final target in targets) {
      if (target.amount.assetId != valuationCurrency.id) {
        return InvalidValuationCurrencyFailure(
          message:
              'Jar target currency '
              '${target.amount.assetId.value} must match valuation currency '
              '${valuationCurrency.id.value}.',
        );
      }
    }

    return const Success(null);
  }
}
