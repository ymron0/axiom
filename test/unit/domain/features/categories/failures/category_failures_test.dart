@Tags(['domain'])
library;

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_in_use_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_kind_mismatch_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('Category failures', () {
    test('CategoryAlreadyActiveFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryAlreadyActiveFailure(message: 'Already active.'),
        CategoryAlreadyActiveFailure.typeId,
      );
    });

    test('CategoryAlreadyDeletedFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryAlreadyDeletedFailure(message: 'Already deleted.'),
        CategoryAlreadyDeletedFailure.typeId,
      );
    });

    test('CategoryAlreadyExistsFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryAlreadyExistsFailure(message: 'Already exists.'),
        CategoryAlreadyExistsFailure.typeId,
      );
    });

    test('CategoryInvalidParentFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryInvalidParentFailure(message: 'Invalid parent.'),
        CategoryInvalidParentFailure.typeId,
      );
    });

    test('CategoryInUseFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryInUseFailure(message: 'In use.'),
        CategoryInUseFailure.typeId,
      );
    });

    test('CategoryKindMismatchFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryKindMismatchFailure(message: 'Kind mismatch.'),
        CategoryKindMismatchFailure.typeId,
      );
    });

    test('CategoryNotFoundFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryNotFoundFailure(message: 'Not found.'),
        CategoryNotFoundFailure.typeId,
      );
    });

    test('CategoryAlreadyArchivedFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryAlreadyArchivedFailure(message: 'Already archived.'),
        CategoryAlreadyArchivedFailure.typeId,
      );
    });

    test('CategoryNotArchivedFailure exposes its typed identity', () {
      _expectFailure(
        const CategoryNotArchivedFailure(message: 'Not archived.'),
        CategoryNotArchivedFailure.typeId,
      );
    });
  });
}

void _expectFailure<T extends BaseFailure>(Failure<T> failure, String typeId) {
  expect(failure.message, isNotNull);
  expect(failure.failureOrNull, same(failure));
  expect(failure.type, typeId);
}
