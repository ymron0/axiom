@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('GetMerchantsUseCase', () {
    late MockMerchantRepository repository;
    late GetMerchantsUseCase useCase;

    setUp(() {
      repository = MockMerchantRepository();
      useCase = GetMerchantsUseCase(repository);
    });

    test('returns repository merchants', () async {
      // Given
      final merchants = [merchantFixture(id: 'all')];
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Merchant>>(merchants));

      // When
      final result = await useCase.call();

      // Then
      expect(result.valueOrNull, same(merchants));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = MerchantNotFoundFailure(message: 'read failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
