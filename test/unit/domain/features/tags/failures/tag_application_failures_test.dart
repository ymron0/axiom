@Tags(['domain'])
library;

import 'package:axiom/src/features/tags/domain/failures/invalid_tag_merge_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/invalid_tag_name_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_in_use_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:test/test.dart';

void main() {
  group('tag application failures', () {
    test('InvalidTagNameFailure exposes stable metadata', () {
      const failure = InvalidTagNameFailure(message: 'invalid');

      expect(failure.type, InvalidTagNameFailure.typeId);
      expect(failure.message, 'invalid');
      expect(failure.failureOrNull, same(failure));
    });

    test('TagNotAssignableFailure exposes stable metadata', () {
      const failure = TagNotAssignableFailure(message: 'archived');

      expect(failure.type, TagNotAssignableFailure.typeId);
      expect(failure.message, 'archived');
      expect(failure.failureOrNull, same(failure));
    });

    test('TagInUseFailure exposes stable metadata', () {
      const failure = TagInUseFailure(message: 'used');

      expect(failure.type, TagInUseFailure.typeId);
      expect(failure.message, 'used');
      expect(failure.failureOrNull, same(failure));
    });

    test('InvalidTagMergeFailure exposes stable metadata', () {
      const failure = InvalidTagMergeFailure(message: 'same');

      expect(failure.type, InvalidTagMergeFailure.typeId);
      expect(failure.message, 'same');
      expect(failure.failureOrNull, same(failure));
    });
  });
}
