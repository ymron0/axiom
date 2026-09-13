import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/search_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('SearchCustodiansUseCase', () {
    late MockCustodianRepository repository;
    late SearchCustodiansUseCase useCase;

    setUp(() {
      repository = MockCustodianRepository();
      useCase = SearchCustodiansUseCase(repository);
    });

    test('returns custodians matching the query', () async {
      // Given
      final custodians = [custodianFixture(id: 'search')];
      when(
        () => repository.search('test'),
      ).thenAnswer((_) async => Success<List<Custodian>>(custodians));

      // When
      final result = await useCase('test');

      // Then
      expect(result.valueOrNull, same(custodians));
      verify(() => repository.search('test')).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = CustodianNotFoundFailure(message: 'search failed');
      when(() => repository.search('test')).thenAnswer((_) async => failure);

      // When
      final result = await useCase('test');

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
