@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/create_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_command_fixtures.dart';
import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('CreateCustodianUseCase', () {
    late MockCustodianRepository repository;
    late CreateCustodianUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(custodianFixture(id: 'fallback'));
    });

    setUp(() {
      repository = MockCustodianRepository();
      useCase = CreateCustodianUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns the created custodian', () async {
      // Given
      final command = createCustodianCommandFixture(
        name: '  Main Bank  ',
        sortOrder: 2,
      );
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(command);

      // Then
      final custodian = result.valueOrNull!;
      expect(custodian, isA<Custodian>());
      expect(custodian.name, 'Main Bank');
      expect(custodian.kind, command.kind);
      expect(custodian.sortOrder, command.sortOrder);
      expect(custodian.createdAt, timestamp);
      expect(custodian.modifiedAt, timestamp);
      expect(custodian.entityVersion, 1);
      expect(custodian.deletedAt, isNull);
      verify(() => repository.create(custodian)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final command = createCustodianCommandFixture();
      const failure = CustodianAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
