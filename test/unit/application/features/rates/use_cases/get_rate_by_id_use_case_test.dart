import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_by_id_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<AssetId>[]);
  });

  group('GetRateByIdUseCase', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository repository;
    late GetRateByIdUseCase useCase;
    late RateId rateId;

    setUp(() {
      assetRepository = MockAssetRepository();
      repository = MockRateRepository();
      useCase = GetRateByIdUseCase(
        repository: repository,
        validateRateAssets: ValidateRateAssetsService(
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
        ),
      );
      rateId = RateId.fromString('rate-1');

      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(
            found: [
              currencyFixture(id: 'EUR', code: 'EUR'),
              currencyFixture(id: 'USD', code: 'USD'),
            ],
            missing: [],
          ),
        ),
      );
    });

    test('returns the repository rate for a successful lookup', () async {
      // Given
      final rate = exchangeRateFixture(id: 'rate-1');
      when(
        () => repository.getById(rateId),
      ).thenAnswer((_) async => Success(rate));

      // When
      final result = await useCase(rateId);

      // Then
      expect(result.valueOrNull, same(rate));
      verify(() => repository.getById(rateId)).called(1);
    });

    test('does not return a rate with a missing referenced asset', () async {
      // Given
      final rate = exchangeRateFixture(id: 'rate-1');
      when(
        () => repository.getById(rateId),
      ).thenAnswer((_) async => Success(rate));
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(found: [], missing: [rate.baseAssetId]),
        ),
      );

      // When
      final result = await useCase(rateId);

      // Then
      expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
    });

    test('propagates a missing-rate failure unchanged', () async {
      // Given
      const failure = RecordNotFoundFailure(message: 'rate missing');
      when(() => repository.getById(rateId)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(rateId);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates another repository failure unchanged', () async {
      // Given
      const failure = RecordAlreadyExistsFailure(message: 'storage failure');
      when(() => repository.getById(rateId)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(rateId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
