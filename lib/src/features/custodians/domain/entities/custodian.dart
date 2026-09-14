import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/mixins/archivable.dart';
import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian.mapper.dart';

/// An institution, service, wallet, or physical location that holds accounts.
///
/// A custodian groups accounts by where those financial positions are held.
/// Examples include a bank, broker, cryptocurrency exchange, wallet provider,
/// or physical cash location.
///
/// The custodian itself does not store account balances or aggregate wealth.
/// Those values are derived from its accounts and their ledger entries.
///
/// ## Visual identity
///
/// [color] and [icon] provide stable visual identity independently of the
/// presentation framework.
///
/// [logo] is optional. When no logo exists, or when the logo cannot be rendered,
/// [icon] is the fallback visual representation.
///
/// ## Ordering
///
/// [sortOrder] provides deterministic user-defined ordering between custodians.
/// It does not express identity or financial importance.
///
/// ## Invariants
///
/// - [name] is trimmed and cannot be blank.
/// - [sortOrder] cannot be negative.
/// - [archivedAt], when present, cannot precede [createdAt] or follow
///   [modifiedAt].
/// - [deletedAt], when present, cannot precede [createdAt].
/// - [deletedAt] cannot precede [archivedAt] when both are present.
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] is greater than zero, as enforced by [AuditedEntity].
@MappableClass()
final class Custodian extends AuditedEntity<CustodianId>
    with Archivable, Deletable, CustodianMappable {
  /// The human-readable custodian name.
  final String name;

  /// The semantic kind of custodian.
  final CustodianKind kind;

  /// An optional logo associated with this custodian.
  final EntityLogo? logo;

  /// The fallback icon and semantic icon identity for this custodian.
  final EntityIcon icon;

  /// The semantic color identity assigned to this custodian.
  final EntityColor color;

  /// The user-defined ordering position of this custodian.
  final int sortOrder;

  /// {@macro archivable.archived_at}
  @override
  final DateTime? archivedAt;

  /// {@macro deletable.deleted_at}
  @override
  final DateTime? deletedAt;

  /// Creates a custodian.
  ///
  /// Throws an [ArgumentError] when [name] is blank or [sortOrder] is negative.
  @MappableConstructor()
  Custodian({
    required super.id,
    required String name,
    required this.kind,
    this.logo,
    required this.icon,
    required this.color,
    required this.sortOrder,
    this.archivedAt,
    this.deletedAt,
    required super.createdAt,
    required super.modifiedAt,
    required super.entityVersion,
  }) : name = normalizeRequiredText(name, 'name') {
    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'Custodian sort order cannot be negative.',
      );
    }
    if (deletedAt?.isBefore(createdAt) ?? false) {
      throw ArgumentError.value(
        deletedAt,
        'deletedAt',
        'Deletion time cannot precede creation time.',
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

    if (archivedAt != null &&
        deletedAt != null &&
        deletedAt!.isBefore(archivedAt!)) {
      throw ArgumentError.value(
        deletedAt,
        'deletedAt',
        'Deletion time cannot precede archive time.',
      );
    }
  }

  /// Creates a new custodian with generated identity and audit metadata.
  factory Custodian.create({
    required String name,
    required CustodianKind kind,
    EntityLogo? logo,
    required EntityIcon icon,
    required EntityColor color,
    required int sortOrder,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Custodian(
      id: CustodianId.generate(),
      name: name,
      kind: kind,
      logo: logo,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      modifiedAt: now,
      entityVersion: 1,
    );
  }
}
