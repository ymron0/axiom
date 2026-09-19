@Tags(['application'])
library;

import 'package:axiom/src/application/services/delete_tag_service.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_in_use_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/tags/tag_fixtures.dart';
import '../../../mocks/tag_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  late MockTagRepository tagRepository;
  late MockTransactionRepository transactionRepository;
  late DeleteTagService service;

  final id = TagId.fromString('tag');
  final deletedAt = DateTime.utc(2026, 9, 19);

  setUp(() {
    tagRepository = MockTagRepository();
    transactionRepository = MockTransactionRepository();

    service = DeleteTagService(
      transactionsExist: TransactionsExistByTagIdUseCase(transactionRepository),
      deleteTag: DeleteTagUseCase(tagRepository),
    );
  });

  test('deletes tag when no transaction references it', () async {
    final deleted = tagFixture(
      id: id.value,
      deletedAt: deletedAt,
      modifiedAt: deletedAt,
    );

    when(
      () => transactionRepository.existsByTagId(id),
    ).thenAnswer((_) async => const Success(false));

    when(
      () => tagRepository.delete(id),
    ).thenAnswer((_) async => Success(deleted));

    final result = await service(id);

    expect(result.valueOrNull, deleted);
  });

  test('blocks deletion while tag is referenced', () async {
    when(
      () => transactionRepository.existsByTagId(id),
    ).thenAnswer((_) async => const Success(true));

    final result = await service(id);

    expect(result.failureOrNull, isA<TagInUseFailure>());

    verifyNever(() => tagRepository.delete(id));
  });

  test('propagates transaction lookup failure', () async {
    const failure = TransactionNotFoundFailure(message: 'query failed');

    when(
      () => transactionRepository.existsByTagId(id),
    ).thenAnswer((_) async => failure);

    final result = await service(id);

    expect(result.failureOrNull, same(failure));

    verifyNever(() => tagRepository.delete(id));
  });

  test('propagates deletion failure', () async {
    const failure = TagNotFoundFailure(message: 'missing');

    when(
      () => transactionRepository.existsByTagId(id),
    ).thenAnswer((_) async => const Success(false));

    when(() => tagRepository.delete(id)).thenAnswer((_) async => failure);

    final result = await service(id);

    expect(result.failureOrNull, same(failure));
  });
}
