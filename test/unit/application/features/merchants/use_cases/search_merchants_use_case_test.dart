import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/search_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('SearchMerchantsUseCase', () {
    late MockMerchantRepository repository;
    late SearchMerchantsUseCase useCase;

    setUp(() {
      repository = MockMerchantRepository();
      useCase = SearchMerchantsUseCase(repository);
    });

    test('returns merchants matching the query', () async {
      // Given
      final merchants = [merchantFixture(id: 'search')];
      when(
        () => repository.search('test'),
      ).thenAnswer((_) async => Success<List<Merchant>>(merchants));

      // When
      final result = await useCase.call('test');

      // Then
      expect(result.valueOrNull, same(merchants));
      verify(() => repository.search('test')).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = MerchantNotFoundFailure(message: 'search failed');
      when(() => repository.search('test')).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call('test');

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
