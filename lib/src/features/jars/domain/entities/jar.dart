import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/mixins/archivable.dart';
import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar.mapper.dart';

/// A logical allocation of money toward a savings or reservation purpose.
///
/// A jar does not own money directly and does not store a mutable balance.
/// Money assigned to the jar is derived from transaction allocations that
/// reference its [id].
///
/// ## Kinds
///
/// [kind] describes the financial purpose of the jar:
///
/// - a savings goal accumulates toward a finite objective;
/// - a sinking fund accumulates for expected future spending; and
/// - a reserve keeps money available until needed.
///
/// ## Target history
///
/// [targets] contains historical, current, and future target configurations.
///
/// Target configurations cannot overlap. At most one target may apply to any
/// calendar date.
///
/// All targets belonging to one jar must use the same currency. Because the
/// application's valuation currency cannot change without resetting the app,
/// the application workflow should ensure that this currency is the configured
/// valuation currency.
///
/// ## Archival
///
/// An archived jar remains persisted and may continue to be referenced by
/// existing historical transactions.
///
/// Archival indicates that the jar is no longer normally available for new
/// allocations. It is not deletion.
///
/// ## Deletion
///
/// Deleted jars are physically removed from persistence by the repository.
///
/// A deleted snapshot may be retained temporarily by the caller for undo or
/// restoration.
///
/// ## Derived data
///
/// The entity deliberately does not store:
///
/// - current balance;
/// - remaining target amount;
/// - progress percentage; or
/// - completion state.
///
/// Those values are derived from transaction allocations.
///
/// ## Invariants
///
/// - [name] is trimmed and cannot be blank.
/// - [description], when supplied, is trimmed and cannot be blank.
/// - [sortOrder] cannot be negative.
/// - target configurations cannot overlap.
/// - all target configurations must use the same currency.
/// - [archivedAt], when present, cannot precede [createdAt].
/// - [archivedAt], when present, cannot follow [modifiedAt].
/// - [deletedAt], when present, cannot precede [createdAt].
/// - when both are present, [deletedAt] cannot precede [archivedAt].
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] must be valid, as enforced by [AuditedEntity].
@MappableClass()
final class Jar extends AuditedEntity<JarId>
    with Archivable, Deletable, JarMappable {
  /// The human-readable jar name.
  final String name;

  /// Optional user-provided details describing the jar's purpose.
  final String? description;

  /// The financial behavior represented by this jar.
  final JarKind kind;

  /// Historical, current, and future target configurations.
  final List<JarTarget> targets;

  /// The semantic icon identity assigned to this jar.
  final EntityIcon icon;

  /// The semantic color identity assigned to this jar.
  final EntityColor color;

  /// The user-defined ordering position of the jar.
  ///
  /// Must be zero or greater.
  final int sortOrder;

  /// {@macro archivable.archived_at}
  @override
  final DateTime? archivedAt;

  /// {@macro deletable.deleted_at}
  @override
  final DateTime? deletedAt;

  /// Creates a jar snapshot.
  ///
  /// This constructor is intended for persistence rehydration and for
  /// constructing an entity with existing identity and lifecycle metadata.
  @MappableConstructor()
  Jar({
    required super.id,
    required String name,
    String? description,
    required this.kind,
    List<JarTarget> targets = const [],
    required this.icon,
    required this.color,
    required this.sortOrder,
    this.archivedAt,
    this.deletedAt,
    required super.createdAt,
    required super.modifiedAt,
    required super.entityVersion,
  }) : targets = List.unmodifiable(targets),
       name = normalizeRequiredText(name, 'name'),
       description = normalizeOptionalText(description, 'description') {
    _validateTargets();

    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'Jar sort order cannot be negative.',
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

    if (deletedAt?.isBefore(createdAt) ?? false) {
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
  }

  /// Creates a new active, non-deleted jar.
  ///
  /// Generates a new [JarId], initializes the entity at version `1`, and uses
  /// the same UTC timestamp for [createdAt] and [modifiedAt].
  ///
  /// Supplying [clock] allows deterministic creation.
  factory Jar.create({
    required String name,
    String? description,
    required JarKind kind,
    List<JarTarget> targets = const [],
    required EntityIcon icon,
    required EntityColor color,
    required int sortOrder,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Jar(
      id: JarId.generate(),
      name: name,
      description: description,
      kind: kind,
      targets: targets,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      modifiedAt: now,
      entityVersion: 1,
    );
  }

  /// Whether this jar contains at least one target configuration.
  bool get hasTarget => targets.isNotEmpty;

  /// Returns the target effective on [date].
  ///
  /// Returns `null` when no target applies on that date.
  JarTarget? targetAt(CalendarDate date) {
    for (final target in targets) {
      if (target.appliesOn(date)) {
        return target;
      }
    }

    return null;
  }

  void _validateTargets() {
    if (targets.isEmpty) {
      return;
    }

    final expectedAssetId = targets.first.amount.assetId;

    for (final target in targets.skip(1)) {
      if (target.amount.assetId != expectedAssetId) {
        throw ArgumentError('All jar targets must use the same currency.');
      }
    }

    final sorted = [...targets]
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];

      if (previous.effectiveUntil == null) {
        throw ArgumentError(
          'An indefinite jar target cannot be followed by another target.',
        );
      }

      if (current.effectiveFrom.isBefore(previous.effectiveUntil!)) {
        throw ArgumentError('Jar target configurations cannot overlap.');
      }
    }
  }
}
