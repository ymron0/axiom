import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/restore_account_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('RestoreAccountUseCase', () {
    late MockAccountRepository repository;
    late RestoreAccountUseCase useCase;

    setUp(() {
      repository = MockAccountRepository();
      useCase = RestoreAccountUseCase(repository);
    });

    test('delegates the deleted snapshot to the repository', () async {
      // Given
      final account = accountFixture(
        id: 'restore',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      when(
        () => repository.restore(account),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(account);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(account)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final account = accountFixture(
        id: 'existing',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      const failure = AccountAlreadyExistsFailure(message: 'existing');
      when(() => repository.restore(account)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(account);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
