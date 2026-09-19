import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/mixins/archivable.dart';
import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag.mapper.dart';

/// Reusable metadata that may be attached to transactions.
///
/// A tag provides an additional classification dimension without participating
/// in transaction allocation.
///
/// Tags are deliberately independent of categories and jars:
///
/// - categories describe what transaction value is allocated to;
/// - jars describe another allocation dimension;
/// - tags describe reusable metadata about the transaction itself.
///
/// A transaction may therefore have zero or more tags independently of its
/// category or jar allocations.
///
/// ## Name semantics
///
/// [name] is normalized using [normalizeTagName].
///
/// Tag-name uniqueness is determined using [tagNameKey]. This means tag names
/// differing only by casing or insignificant whitespace represent conflicting
/// names.
///
/// The entity itself cannot enforce uniqueness because uniqueness requires
/// knowledge of other persisted tags. That rule is enforced by the repository
/// operation.
///
/// ## Archival
///
/// Archiving prevents a tag from being offered for new assignments while
/// preserving the tag and its historical transaction references.
///
/// Existing transactions may therefore continue referencing an archived tag.
///
/// ## Deletion
///
/// Deletion is only valid after cross-feature reference checks have established
/// that no persisted transaction references the tag.
///
/// The entity represents deletion state but does not perform that cross-feature
/// lookup itself.
///
/// ## Invariants
///
/// - [name] is normalized and cannot be blank.
/// - [archivedAt], when present, cannot precede [createdAt].
/// - [archivedAt], when present, cannot follow [modifiedAt].
/// - [deletedAt], when present, cannot precede [createdAt].
/// - [deletedAt] cannot precede [archivedAt] when both are present.
/// - inherited audit metadata remains valid.
/// - [entityVersion] is greater than zero.
@MappableClass()
final class Tag extends AuditedEntity<TagId>
    with Archivable, Deletable, TagMappable {
  /// The normalized display name of this tag.
  final String name;

  /// {@macro archivable.archived_at}
  @override
  final DateTime? archivedAt;

  /// {@macro deletable.deleted_at}
  @override
  final DateTime? deletedAt;

  /// Creates a persisted tag snapshot.
  Tag({
    required super.id,
    required String name,
    required super.createdAt,
    required super.modifiedAt,
    this.archivedAt,
    this.deletedAt,
    required super.entityVersion,
  }) : name = normalizeTagName(name) {
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

  /// Creates a new active tag.
  factory Tag.create({required String name, Clock? clock}) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Tag(
      id: TagId.generate(),
      name: name,
      createdAt: now,
      modifiedAt: now,
      entityVersion: 1,
    );
  }
}
