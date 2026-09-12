import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant.mapper.dart';

/// Represents a canonical merchant associated with transactions.
///
/// Categories associated with a merchant are derived from the transaction
/// splits of transactions referencing the merchant rather than stored here.
///
/// Transaction statistics such as total spending, transaction count, and
/// last-used date are also derived from transactions.
///
/// The [name] is trimmed and cannot be blank.
/// When present, [deletedAt] cannot precede [createdAt].
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
