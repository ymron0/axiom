import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:test/test.dart';

void main() {
  group('Deletable', () {
    test('reports an entity with no deletion timestamp as active', () {
      // Given
      final entity = TestDeletable(null);

      // When
      final isDeleted = entity.isDeleted;

      // Then
      expect(isDeleted, isFalse);
    });

    test('reports an entity with a deletion timestamp as deleted', () {
      // Given
      final deletedAt = DateTime.utc(2026, 9, 12, 10, 30);
      final entity = TestDeletable(deletedAt);

      // When
      final isDeleted = entity.isDeleted;

      // Then
      expect(entity.deletedAt, same(deletedAt));
      expect(isDeleted, isTrue);
    });
  });
}

final class TestDeletable with Deletable {
  TestDeletable(this.deletedAt);

  @override
  final DateTime? deletedAt;
}
