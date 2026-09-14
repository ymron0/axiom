import 'package:axiom/src/core/domain/mixins/archivable.dart';
import 'package:test/test.dart';

void main() {
  group('Archivable', () {
    test('reports an entity with no archive timestamp as active', () {
      final entity = _TestArchivable(null);

      expect(entity.archivedAt, isNull);
      expect(entity.isArchived, isFalse);
    });

    test('reports an entity with an archive timestamp as archived', () {
      final archivedAt = DateTime.utc(2026, 9, 14, 10, 30);
      final entity = _TestArchivable(archivedAt);

      expect(entity.archivedAt, same(archivedAt));
      expect(entity.isArchived, isTrue);
    });
  });
}

final class _TestArchivable with Archivable {
  _TestArchivable(this.archivedAt);

  @override
  final DateTime? archivedAt;
}
