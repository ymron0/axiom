@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/delete_account_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('DeleteAccountUseCase', () {
    late MockAccountRepository repository;
    late DeleteAccountUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = DeleteAccountUseCase(repository);
    });

    test('returns the deleted account snapshot', () async {
      // Given
      final account = accountFixture(
        id: 'delete',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.delete(account.id),
      ).thenAnswer((_) async => Success(account));

      // When
      final result = await useCase(account.id);

      // Then
      expect(result.valueOrNull, same(account));
      expect(result.valueOrNull?.deletedAt, isNotNull);
      verify(() => repository.delete(account.id)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final account = accountFixture(id: 'missing');
      const failure = AccountNotFoundFailure(message: 'missing');
      when(
        () => repository.delete(account.id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(account.id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
