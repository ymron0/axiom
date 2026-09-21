import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'settings_valuation_currency_change_not_allowed_failure.mapper.dart';

/// Indicates that an update attempted to change the valuation currency.
///
/// The valuation currency is immutable after settings initialization because
/// persisted monetary values, including transaction valuation amounts, are
/// expressed in that currency.
///
/// Changing the valuation currency requires an application reset.
@MappableClass()
final class SettingsValuationCurrencyChangeNotAllowedFailure
    extends Failure<SettingsValuationCurrencyChangeNotAllowedFailure>
    with SettingsValuationCurrencyChangeNotAllowedFailureMappable
    implements SettingsFailure {
  /// Stable identifier for this failure kind.
  static const typeId = 'settings.valuationCurrencyChangeNotAllowed';

  /// Creates the failure.
  const SettingsValuationCurrencyChangeNotAllowedFailure({
    required String message,
  }) : super(message);

  @override
  SettingsValuationCurrencyChangeNotAllowedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
