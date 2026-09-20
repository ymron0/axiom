@Tags(['application'])
library;

import 'package:axiom/src/application/services/assign_tag_to_transaction_service.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_id_use_case.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_repository_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
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
  late AssignTagToTransactionService service;

  final timestamp = DateTime.utc(2026, 9, 19, 12);
  final tagId = TagId.fromString('business');
  final transactionId = TransactionId.fromString('transaction');

  setUpAll(() {
    registerFallbackValue(TagId.fromString('fallback'));
    registerFallbackValue(transactionFixture(id: 'fallback'));
  });

  setUp(() {
    tagRepository = MockTagRepository();
    transactionRepository = MockTransactionRepository();

    service = AssignTagToTransactionService(
      clock: FixedClock(timestamp),
      getTransactionById: GetTransactionByIdUseCase(transactionRepository),
      getTagById: GetTagByIdUseCase(tagRepository),
      updateTransaction: UpdateTransactionUseCase(transactionRepository),
    );
  });

  test('assigns active tag and persists updated transaction', () async {
    final transaction = transactionFixture(id: transactionId.value);
    final tag = tagFixture(id: tagId.value);

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(
      () => tagRepository.getById(tagId),
    ).thenAnswer((_) async => Success(tag));

    when(
      () => transactionRepository.update(any()),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(transactionId: transactionId, tagId: tagId);

    final updated = result.valueOrNull!;

    expect(updated.tagIds, [tagId]);
    expect(updated.modifiedAt, timestamp);

    final captured =
        verify(() => transactionRepository.update(captureAny())).captured.single
            as Transaction;

    expect(captured, updated);
  });

  test('assignment is idempotent when tag is already present', () async {
    final transaction = transactionFixture(
      id: transactionId.value,
      tagIds: [tagId],
    );

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.valueOrNull, same(transaction));

    verifyNever(() => tagRepository.getById(any()));
    verifyNever(() => transactionRepository.update(any()));
  });

  test('returns not-found when transaction does not exist', () async {
    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => const Success<Transaction?>(null));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
  });

  test('propagates transaction lookup failure', () async {
    const failure = TransactionNotFoundFailure(message: 'lookup failed');

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => failure);

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, same(failure));
  });

  test('returns tag not-found when tag does not exist', () async {
    final transaction = transactionFixture(id: transactionId.value);

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(
      () => tagRepository.getById(tagId),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, isA<TagNotFoundFailure>());

    verifyNever(() => transactionRepository.update(any()));
  });

  test('rejects archived tag', () async {
    final transaction = transactionFixture(id: transactionId.value);
    final archivedAt = DateTime.utc(2026, 9, 18);

    final tag = tagFixture(
      id: tagId.value,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(
      () => tagRepository.getById(tagId),
    ).thenAnswer((_) async => Success(tag));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, isA<TagNotAssignableFailure>());

    verifyNever(() => transactionRepository.update(any()));
  });

  test('propagates tag lookup failure', () async {
    final transaction = transactionFixture(id: transactionId.value);
    const failure = TagRepositoryFailure(message: 'failed');

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(() => tagRepository.getById(tagId)).thenAnswer((_) async => failure);

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, same(failure));
  });

  test('propagates transaction update failure', () async {
    final transaction = transactionFixture(id: transactionId.value);
    final tag = tagFixture(id: tagId.value);

    const failure = TransactionVersionConflictFailure(message: 'conflict');

    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(
      () => tagRepository.getById(tagId),
    ).thenAnswer((_) async => Success(tag));

    when(
      () => transactionRepository.update(any()),
    ).thenAnswer((_) async => failure);

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, same(failure));
  });
}
