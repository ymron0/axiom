import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_persistence_failure.mapper.dart';

/// Indicates that a merchant persistence operation could not be completed.
///
/// This failure represents infrastructure-level problems encountered while
/// reading or writing merchant persistence.
///
/// Examples include:
///
/// - an underlying database operation failing;
/// - a filesystem operation failing;
/// - a persisted merchant record having an invalid structure;
/// - a persisted merchant no longer satisfying current domain invariants.
///
/// Storage-specific exceptions must not escape through [MerchantRepository].
/// They are translated into this failure at the persistent repository
/// boundary.
@MappableClass()
final class MerchantPersistenceFailure
    extends Failure<MerchantPersistenceFailure>
    with MerchantPersistenceFailureMappable
    implements MerchantFailure {
  /// Creates a merchant persistence failure with optional details.
  const MerchantPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.persistence';

  @override
  MerchantPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
