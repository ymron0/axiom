import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('GetAccountsUseCase', () {
    late MockAccountRepository repository;
    late GetAccountsUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = GetAccountsUseCase(repository);
    });

    test('returns repository accounts', () async {
      // Given
      final accounts = [accountFixture(id: 'all')];
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(accounts));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = AccountNotFoundFailure(message: 'read failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
