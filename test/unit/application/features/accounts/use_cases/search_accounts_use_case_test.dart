@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/search_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('SearchAccountsUseCase', () {
    late MockAccountRepository repository;
    late SearchAccountsUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = SearchAccountsUseCase(repository);
    });

    test('returns accounts matching the query', () async {
      // Given
      final accounts = [accountFixture(id: 'search')];
      when(
        () => repository.search('test'),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));

      // When
      final result = await useCase('test');

      // Then
      expect(result.valueOrNull, same(accounts));
      verify(() => repository.search('test')).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = AccountNotFoundFailure(message: 'search failed');
      when(() => repository.search('test')).thenAnswer((_) async => failure);

      // When
      final result = await useCase('test');

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
