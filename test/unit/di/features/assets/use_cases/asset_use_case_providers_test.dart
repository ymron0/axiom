import 'package:axiom/src/features/assets/application/use_cases/create_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_asset_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_code_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_asset_use_case.dart';
import 'package:axiom/src/features/assets/data/repositories/in_memory_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/di/create_all_assets_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/create_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_code_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_assets_by_ids_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/update_all_assets_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/update_asset_use_case_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('asset use-case providers', () {
    test('resolves every use case from the default repository', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(assetRepositoryProvider);
      final useCases = [
        container.read(createAssetUseCaseProvider),
        container.read(createAllAssetsUseCaseProvider),
        container.read(getAssetUseCaseProvider),
        container.read(getAssetByIdUseCaseProvider),
        container.read(getAssetByCodeUseCaseProvider),
        container.read(getAssetsByIdsUseCaseProvider),
        container.read(updateAssetUseCaseProvider),
        container.read(updateAllAssetsUseCaseProvider),
      ];

      // Then
      expect(repository, isA<InMemoryAssetRepositoryImpl>());
      expect(useCases, hasLength(8));
      expect(useCases[0], isA<CreateAssetUseCase>());
      expect(useCases[1], isA<CreateAllAssetsUseCase>());
      expect(useCases[2], isA<GetAssetUseCase>());
      expect(useCases[3], isA<GetAssetByIdUseCase>());
      expect(useCases[4], isA<GetAssetByCodeUseCase>());
      expect(useCases[5], isA<GetAssetsByIdsUseCase>());
      expect(useCases[6], isA<UpdateAssetUseCase>());
      expect(useCases[7], isA<UpdateAllAssetsUseCase>());
    });

    test('uses an overridden repository for the create-all use case', () async {
      // Given
      final repository = MockAssetRepository();
      final assets = [currencyFixture(id: 'provider-asset', code: 'AAA')];
      when(
        () => repository.createAll(assets),
      ).thenAnswer((_) async => Success<List<Asset>>(assets));
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      // When
      final result = await container
          .read(createAllAssetsUseCaseProvider)
          .call(assets);

      // Then
      expect(result.valueOrNull, same(assets));
      verify(() => repository.createAll(assets)).called(1);
    });
  });
}
