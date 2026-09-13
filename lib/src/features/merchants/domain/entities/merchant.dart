import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant.mapper.dart';

/// A canonical merchant associated with transactions.
///
/// A merchant identifies the counterparty associated with one or more
/// transactions.
///
/// ## Derived data
///
/// Categories associated with a merchant are derived from the splits of its
/// transactions rather than stored on the merchant.
///
/// Statistics such as total spending, transaction count, and last-used date
/// are also derived from transactions.
///
/// ## Invariants
///
/// - [name] is trimmed and cannot be blank.
/// - [deletedAt], when present, cannot precede [createdAt].
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] is greater than zero, as enforced by [AuditedEntity].
@MappableClass()
final class Merchant extends AuditedEntity<MerchantId>
    with Deletable, MerchantMappable {
  /// The canonical display name of the merchant.
  final String name;

  @override
  final DateTime? deletedAt;

  /// Creates a merchant
  Merchant({
    required super.id,
    required String name,
    required super.createdAt,
    required super.modifiedAt,
    this.deletedAt,
    required super.entityVersion,
  }) : name = normalizeRequiredText(name, 'name') {
    if (deletedAt != null && deletedAt!.isBefore(createdAt)) {
      throw ArgumentError.value(
        deletedAt,
        'deletedAt',
        'Deletion time cannot precede creation time.',
      );
    }
  }

  /// Creates a new merchant.
  factory Merchant.create({required String name, Clock? clock}) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Merchant(
      id: MerchantId.generate(),
      name: name,
      createdAt: now,
      modifiedAt: now,
      entityVersion: 1,
    );
  }
}
