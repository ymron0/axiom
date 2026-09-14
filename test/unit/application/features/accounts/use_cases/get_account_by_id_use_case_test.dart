@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('GetAccountByIdUseCase', () {
    late MockAccountRepository repository;
    late GetAccountByIdUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = GetAccountByIdUseCase(repository);
    });

    test('returns the account matching the ID', () async {
      // Given
      final account = accountFixture(id: 'by-id');
      when(
        () => repository.getById(account.id),
      ).thenAnswer((_) async => Success<Account?>(account));

      // When
      final result = await useCase(account.id);

      // Then
      expect(result.valueOrNull, same(account));
      verify(() => repository.getById(account.id)).called(1);
    });

    test('returns null when the account is absent', () async {
      // Given
      final id = AccountId.fromString('missing');
      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => const Success<Account?>(null));

      // When
      final result = await useCase(id);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('propagates repository failures', () async {
      // Given
      final id = AccountId.fromString('failure');
      const failure = AccountNotFoundFailure(message: 'read failed');
      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
