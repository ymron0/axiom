@Tags(['application'])
library;

import 'package:axiom/src/application/services/remove_tag_from_transaction_service.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  late MockTransactionRepository repository;
  late RemoveTagFromTransactionService service;

  final timestamp = DateTime.utc(2026, 9, 19, 12);
  final tagId = TagId.fromString('business');
  final otherId = TagId.fromString('other');
  final transactionId = TransactionId.fromString('transaction');

  setUpAll(() {
    registerFallbackValue(transactionFixture(id: 'fallback'));
  });

  setUp(() {
    repository = MockTransactionRepository();

    service = RemoveTagFromTransactionService(
      clock: FixedClock(timestamp),
      getTransactionById: GetTransactionByIdUseCase(repository),
      updateTransaction: UpdateTransactionUseCase(repository),
    );
  });

  test('removes tag while preserving remaining order', () async {
    final transaction = transactionFixture(
      id: transactionId.value,
      tagIds: [tagId, otherId],
    );

    when(
      () => repository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(
      () => repository.update(any()),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.valueOrNull!.tagIds, [otherId]);
    expect(result.valueOrNull!.modifiedAt, timestamp);
  });

  test('removal is idempotent when tag is absent', () async {
    final transaction = transactionFixture(id: transactionId.value);

    when(
      () => repository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.valueOrNull, same(transaction));

    verifyNever(() => repository.update(any()));
  });

  test('returns not-found when transaction is absent', () async {
    when(
      () => repository.getById(transactionId),
    ).thenAnswer((_) async => const Success<Transaction?>(null));

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
  });

  test('propagates lookup failure', () async {
    const failure = TransactionNotFoundFailure(message: 'failed');

    when(
      () => repository.getById(transactionId),
    ).thenAnswer((_) async => failure);

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, same(failure));
  });

  test('propagates update failure', () async {
    final transaction = transactionFixture(
      id: transactionId.value,
      tagIds: [tagId],
    );

    const failure = TransactionVersionConflictFailure(message: 'conflict');

    when(
      () => repository.getById(transactionId),
    ).thenAnswer((_) async => Success<Transaction?>(transaction));

    when(() => repository.update(any())).thenAnswer((_) async => failure);

    final result = await service(transactionId: transactionId, tagId: tagId);

    expect(result.failureOrNull, same(failure));
  });
}
