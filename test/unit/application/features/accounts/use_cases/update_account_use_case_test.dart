import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/update_account_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('UpdateAccountUseCase', () {
    late MockAccountRepository repository;
    late UpdateAccountUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = UpdateAccountUseCase(repository);
    });

    test('delegates the account to the repository', () async {
      // Given
      final account = accountFixture(id: 'update');
      when(
        () => repository.update(account),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(account);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(account)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final account = accountFixture(id: 'missing');
      const failure = AccountNotFoundFailure(message: 'missing');
      when(() => repository.update(account)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(account);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
