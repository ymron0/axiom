@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('GetCustodiansUseCase', () {
    late MockCustodianRepository repository;
    late GetCustodiansUseCase useCase;

    setUp(() {
      repository = MockCustodianRepository();
      useCase = GetCustodiansUseCase(repository);
    });

    test('returns repository custodians', () async {
      // Given
      final custodians = [custodianFixture(id: 'all')];
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>(custodians));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(custodians));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = CustodianNotFoundFailure(message: 'read failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
