import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/create_account_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/accounts/account_command_fixtures.dart';
import '../../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../../mocks/account_repository_mock.dart';

void main() {
  group('CreateAccountUseCase', () {
    late MockAccountRepository repository;
    late CreateAccountUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(accountFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockAccountRepository();
      useCase = CreateAccountUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns the created account', () async {
      // Given
      final command = createAccountCommandFixture(
        name: '  Savings  ',
        reference: '  CH12 3456  ',
        sortOrder: 2,
      );
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      final account = result.valueOrNull!;
      expect(account, isA<Account>());
      expect(account.name, 'Savings');
      expect(account.reference, 'CH12 3456');
      expect(account.custodianId, command.custodianId);
      expect(account.denominationAssetId, command.denominationAssetId);
      expect(account.kind, command.kind);
      expect(account.sortOrder, command.sortOrder);
      expect(account.createdAt, timestamp);
      expect(account.modifiedAt, timestamp);
      expect(account.entityVersion, 1);
      expect(account.deletedAt, isNull);
      verify(() => repository.create(account)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final command = createAccountCommandFixture();
      const failure = AccountAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
