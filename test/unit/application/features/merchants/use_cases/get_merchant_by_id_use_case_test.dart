@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_merchant_by_id_use_case.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  group('GetMerchantByIdUseCase', () {
    late MockMerchantRepository repository;
    late GetMerchantByIdUseCase useCase;

    setUp(() {
      repository = MockMerchantRepository();
      useCase = GetMerchantByIdUseCase(repository);
    });

    test('returns the merchant matching the ID', () async {
      // Given
      final merchant = merchantFixture(id: 'by-id');
      when(
        () => repository.getById(merchant.id),
      ).thenAnswer((_) async => Success<Merchant?>(merchant));

      // When
      final result = await useCase.call(merchant.id);

      // Then
      expect(result.valueOrNull, same(merchant));
      verify(() => repository.getById(merchant.id)).called(1);
    });

    test('returns null when the merchant is absent', () async {
      // Given
      final id = MerchantId.fromString('missing');
      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => const Success<Merchant?>(null));

      // When
      final result = await useCase.call(id);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('propagates repository failures', () async {
      // Given
      final id = MerchantId.fromString('failure');
      const failure = MerchantNotFoundFailure(message: 'read failed');
      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
