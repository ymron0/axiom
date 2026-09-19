@Tags(['domain'])
library;

import 'package:axiom/src/features/tags/domain/failures/tag_already_active_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_deleted_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_in_use_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_name_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('Tag failures', () {
    test('TagAlreadyExistsFailure exposes its stable type', () {
      const failure = TagAlreadyExistsFailure(message: 'duplicate');

      expect(failure.type, TagAlreadyExistsFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'duplicate');
    });

    test('TagNameAlreadyExistsFailure exposes its stable type', () {
      const failure = TagNameAlreadyExistsFailure(message: 'duplicate name');

      expect(failure.type, TagNameAlreadyExistsFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'duplicate name');
    });

    test('TagNotFoundFailure exposes its stable type', () {
      const failure = TagNotFoundFailure(message: 'missing');

      expect(failure.type, TagNotFoundFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'missing');
    });

    test('TagAlreadyDeletedFailure exposes its stable type', () {
      const failure = TagAlreadyDeletedFailure(message: 'deleted');

      expect(failure.type, TagAlreadyDeletedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'deleted');
    });

    test('TagAlreadyArchivedFailure exposes its stable type', () {
      const failure = TagAlreadyArchivedFailure(message: 'archived');

      expect(failure.type, TagAlreadyArchivedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'archived');
    });

    test('TagNotArchivedFailure exposes its stable type', () {
      const failure = TagNotArchivedFailure(message: 'active');

      expect(failure.type, TagNotArchivedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'active');
    });

    test('TagAlreadyActiveFailure exposes its stable type', () {
      const failure = TagAlreadyActiveFailure(message: 'active');

      expect(failure.type, TagAlreadyActiveFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'active');
    });

    test('TagInUseFailure exposes its stable type', () {
      const failure = TagInUseFailure(message: 'in use');

      expect(failure.type, TagInUseFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'in use');
    });

    test('TagPersistenceFailure exposes its stable type', () {
      const failure = TagPersistenceFailure(message: 'storage');

      expect(failure.type, TagPersistenceFailure.typeId);
      expect(failure.failureOrNull, same(failure));
      expect(failure.message, 'storage');
    });
  });
}
