import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/mixins/archivable.dart';
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
/// - [id] cannot be [MerchantId.self], which is reserved for the absence of
///   a merchant.
/// - [archivedAt], when present, cannot precede [createdAt] or follow
///   [modifiedAt].
/// - [deletedAt], when present, cannot precede [createdAt].
/// - [deletedAt] cannot precede [archivedAt] when both are present.
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] is greater than zero, as enforced by [AuditedEntity].
@MappableClass()
final class Merchant extends AuditedEntity<MerchantId>
    with Archivable, Deletable, MerchantMappable {
  /// The canonical display name of the merchant.
  final String name;

  /// {@macro archivable.archived_at}
  @override
  final DateTime? archivedAt;

  @override
  final DateTime? deletedAt;

  /// Creates a merchant
  Merchant({
    required super.id,
    required String name,
    required super.createdAt,
    required super.modifiedAt,
    this.archivedAt,
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

    if (archivedAt != null &&
        deletedAt != null &&
        deletedAt!.isBefore(archivedAt!)) {
      throw ArgumentError.value(
        deletedAt,
        'deletedAt',
        'Deletion time cannot precede archive time.',
      );
    }

    if (archivedAt?.isBefore(createdAt) ?? false) {
      throw ArgumentError.value(
        archivedAt,
        'archivedAt',
        'Archive time cannot precede creation time.',
      );
    }

    if (archivedAt?.isAfter(modifiedAt) ?? false) {
      throw ArgumentError.value(
        archivedAt,
        'archivedAt',
        'Archive time cannot follow modification time.',
      );
    }

    if (id.isSelf) {
      throw ArgumentError.value(
        id,
        'id',
        'MerchantId.self is reserved and cannot represent a persisted merchant.',
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
