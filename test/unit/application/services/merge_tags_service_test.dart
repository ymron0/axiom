@Tags(['application'])
library;

import 'package:axiom/src/application/services/merge_tags_service.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/archive_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_id_use_case.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/invalid_tag_merge_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_in_use_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_repository_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/tags/tag_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  late MockTagRepository tagRepository;
  late MockTransactionRepository transactionRepository;
  late MergeTagsService service;

  final timestamp = DateTime.utc(2026, 9, 19, 12);

  final sourceId = TagId.fromString('source');
  final targetId = TagId.fromString('target');
  final otherId = TagId.fromString('other');

  setUpAll(() {
    registerFallbackValue(TagId.fromString('fallback'));
    registerFallbackValue(transactionFixture(id: 'fallback'));
  });

  setUp(() {
    tagRepository = MockTagRepository();
    transactionRepository = MockTransactionRepository();

    service = MergeTagsService(
      clock: FixedClock(timestamp),
      getTagById: GetTagByIdUseCase(tagRepository),
      archiveTag: ArchiveTagUseCase(
        repository: tagRepository,
        clock: FixedClock(timestamp),
      ),
      getTransactionsByTagId: GetTransactionsByTagIdUseCase(
        transactionRepository,
      ),
      updateTransaction: UpdateTransactionUseCase(transactionRepository),
      transactionsExistByTagId: TransactionsExistByTagIdUseCase(
        transactionRepository,
      ),
      deleteTag: DeleteTagUseCase(tagRepository),
    );
  });

  test('rejects merging a tag into itself', () async {
    final result = await service(sourceTagId: sourceId, targetTagId: sourceId);

    expect(result.failureOrNull, isA<InvalidTagMergeFailure>());

    verifyNever(() => tagRepository.getById(any()));
  });

  test('returns not-found when source does not exist', () async {
    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => const Success<Tag?>(null));

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, isA<TagNotFoundFailure>());
  });

  test('propagates source lookup failure', () async {
    const failure = TagRepositoryFailure(message: 'failed');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));
  });

  test('returns not-found when target does not exist', () async {
    final source = tagFixture(id: sourceId.value);

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => const Success<Tag?>(null));

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, isA<TagNotFoundFailure>());
  });

  test('propagates target lookup failure', () async {
    final source = tagFixture(id: sourceId.value);
    const failure = TagRepositoryFailure(message: 'target failed');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));
  });

  test('rejects archived merge target', () async {
    final source = tagFixture(id: sourceId.value);

    final target = tagFixture(
      id: targetId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, isA<TagNotAssignableFailure>());
  });

  test('archives active source before moving references', () async {
    final source = tagFixture(id: sourceId.value);
    final target = tagFixture(id: targetId.value);

    final archivedSource = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => tagRepository.archive(sourceId, timestamp),
    ).thenAnswer((_) async => Success(archivedSource));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(<Transaction>[]));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(false));

    when(() => tagRepository.delete(sourceId)).thenAnswer(
      (_) async => Success(
        tagFixture(
          id: sourceId.value,
          archivedAt: timestamp,
          modifiedAt: timestamp,
          deletedAt: timestamp,
        ),
      ),
    );

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.valueOrNull, target);

    verify(() => tagRepository.archive(sourceId, timestamp)).called(1);
  });

  test('does not archive source again when already archived', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(<Transaction>[]));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(false));

    when(() => tagRepository.delete(sourceId)).thenAnswer(
      (_) async => Success(
        tagFixture(
          id: sourceId.value,
          archivedAt: timestamp,
          modifiedAt: timestamp,
          deletedAt: timestamp,
        ),
      ),
    );

    await service(sourceTagId: sourceId, targetTagId: targetId);

    verifyNever(() => tagRepository.archive(any(), any()));
  });

  test('propagates archival failure without touching transactions', () async {
    final source = tagFixture(id: sourceId.value);
    final target = tagFixture(id: targetId.value);

    const failure = TagRepositoryFailure(message: 'archive failed');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => tagRepository.archive(sourceId, timestamp),
    ).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));

    verifyNever(() => transactionRepository.getTransactionsByTagId(any()));
  });

  test('replaces source tag while preserving tag order', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    final transaction = transactionFixture(
      id: 'transaction',
      tagIds: [otherId, sourceId],
    );

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => Success([transaction]));

    when(
      () => transactionRepository.update(any()),
    ).thenAnswer((_) async => const Success(null));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(false));

    when(() => tagRepository.delete(sourceId)).thenAnswer(
      (_) async => Success(
        tagFixture(
          id: sourceId.value,
          archivedAt: timestamp,
          modifiedAt: timestamp,
          deletedAt: timestamp,
        ),
      ),
    );

    await service(sourceTagId: sourceId, targetTagId: targetId);

    final updated =
        verify(() => transactionRepository.update(captureAny())).captured.single
            as Transaction;

    expect(updated.tagIds, [otherId, targetId]);
    expect(updated.modifiedAt, timestamp);
  });

  test('removes source without duplicating existing target', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    final transaction = transactionFixture(
      id: 'transaction',
      tagIds: [targetId, sourceId, otherId],
    );

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => Success([transaction]));

    when(
      () => transactionRepository.update(any()),
    ).thenAnswer((_) async => const Success(null));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(false));

    when(() => tagRepository.delete(sourceId)).thenAnswer(
      (_) async => Success(
        tagFixture(
          id: sourceId.value,
          archivedAt: timestamp,
          modifiedAt: timestamp,
          deletedAt: timestamp,
        ),
      ),
    );

    await service(sourceTagId: sourceId, targetTagId: targetId);

    final updated =
        verify(() => transactionRepository.update(captureAny())).captured.single
            as Transaction;

    expect(updated.tagIds, [targetId, otherId]);
  });

  test('propagates transaction query failure', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    const failure = TransactionNotFoundFailure(message: 'query failed');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));
  });

  test('update failure leaves source undeleted for safe retry', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    final transaction = transactionFixture(
      id: 'transaction',
      tagIds: [sourceId],
    );

    const failure = TransactionVersionConflictFailure(message: 'conflict');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => Success([transaction]));

    when(
      () => transactionRepository.update(any()),
    ).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));

    verifyNever(() => tagRepository.delete(sourceId));
  });

  test('final reference check protects against concurrent reference', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(<Transaction>[]));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(true));

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, isA<TagInUseFailure>());

    verifyNever(() => tagRepository.delete(sourceId));
  });

  test('propagates final reference-check failure', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    const failure = TransactionNotFoundFailure(message: 'check failed');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(<Transaction>[]));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));
  });

  test('propagates final deletion failure', () async {
    final source = tagFixture(
      id: sourceId.value,
      archivedAt: timestamp,
      modifiedAt: timestamp,
    );

    final target = tagFixture(id: targetId.value);

    const failure = TagNotFoundFailure(message: 'delete failed');

    when(
      () => tagRepository.getById(sourceId),
    ).thenAnswer((_) async => Success(source));

    when(
      () => tagRepository.getById(targetId),
    ).thenAnswer((_) async => Success(target));

    when(
      () => transactionRepository.getTransactionsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(<Transaction>[]));

    when(
      () => transactionRepository.existsByTagId(sourceId),
    ).thenAnswer((_) async => const Success(false));

    when(() => tagRepository.delete(sourceId)).thenAnswer((_) async => failure);

    final result = await service(sourceTagId: sourceId, targetTagId: targetId);

    expect(result.failureOrNull, same(failure));
  });
}
