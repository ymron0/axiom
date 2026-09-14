@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('GetAccountsByCustodianIdUseCase', () {
    late MockAccountRepository repository;
    late GetAccountsByCustodianIdUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = GetAccountsByCustodianIdUseCase(repository);
    });

    test('returns accounts belonging to the custodian', () async {
      // Given
      final account = accountFixture(id: 'custodian');
      final accounts = [account];
      when(
        () => repository.getByCustodianId(account.custodianId),
      ).thenAnswer((_) async => Success<List<Account>>(accounts));

      // When
      final result = await useCase(account.custodianId);

      // Then
      expect(result.valueOrNull, same(accounts));
      verify(() => repository.getByCustodianId(account.custodianId)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final account = accountFixture(id: 'failure');
      const failure = AccountNotFoundFailure(message: 'read failed');
      when(
        () => repository.getByCustodianId(account.custodianId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(account.custodianId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
