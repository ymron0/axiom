import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_valuation_unavailable_failure.mapper.dart';

/// Indicates that an account balance exists but cannot currently be valued in
/// the configured valuation Currency.
@MappableClass()
final class AccountValuationUnavailableFailure
    extends Failure<AccountValuationUnavailableFailure>
    with AccountValuationUnavailableFailureMappable {
  /// Stable identifier for this failure kind.
  static const typeId = 'application.accountValuationUnavailable';

  /// Creates the failure.
  const AccountValuationUnavailableFailure({required String message})
    : super(message);

  @override
  AccountValuationUnavailableFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
