import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';

/// Creates a valid tag snapshot for tests.
Tag tagFixture({
  String id = 'tag-1',
  String name = 'Tag',
  DateTime? createdAt,
  DateTime? modifiedAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
  int entityVersion = 1,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);

  return Tag(
    id: TagId.fromString(id),
    name: name,
    createdAt: created,
    modifiedAt: modifiedAt ?? archivedAt ?? created,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    entityVersion: entityVersion,
  );
}
