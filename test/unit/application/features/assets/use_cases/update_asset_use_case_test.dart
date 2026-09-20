@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/failures/asset_type_change_not_allowed_failure.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_asset_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  late MockAssetRepository repository;
  late UpdateAssetUseCase useCase;

  setUpAll(() {
    registerFallbackValue(currencyFixture(id: 'fallback-asset'));
  });

  setUp(() {
    repository = MockAssetRepository();
    useCase = UpdateAssetUseCase(repository);
  });

  test('updates an asset when its concrete type is unchanged', () async {
    final existing = currencyFixture(id: 'currency', name: 'Old');
    final updated = currencyFixture(id: 'currency', name: 'New');
    when(
      () => repository.getById(existing.id),
    ).thenAnswer((_) async => Success<Asset?>(existing));
    when(
      () => repository.update(updated),
    ).thenAnswer((_) async => Success<Asset>(updated));

    final result = await useCase(updated);

    expect(result.valueOrNull, same(updated));
    verify(() => repository.update(updated)).called(1);
  });

  test('returns not found without updating', () async {
    final asset = currencyFixture(id: 'missing');
    when(
      () => repository.getById(asset.id),
    ).thenAnswer((_) async => const Success<Asset?>(null));

    final result = await useCase(asset);

    expect(result.failureOrNull, isA<AssetNotFoundFailure>());
    verifyNever(() => repository.update(any()));
  });

  test('rejects changing the concrete subtype', () async {
    final existing = currencyFixture(id: 'same-id');
    final replacement = cryptoAssetFixture(id: 'same-id');
    when(
      () => repository.getById(existing.id),
    ).thenAnswer((_) async => Success<Asset?>(existing));

    final result = await useCase(replacement);

    expect(result.failureOrNull, isA<AssetTypeChangeNotAllowedFailure>());
    verifyNever(() => repository.update(any()));
  });

  test('preserves lookup failures', () async {
    final asset = currencyFixture(id: 'failed');
    const failure = AssetRepositoryFailure(message: 'lookup failed');
    when(() => repository.getById(asset.id)).thenAnswer((_) async => failure);

    final result = await useCase(asset);

    expect(result.failureOrNull, same(failure));
    verifyNever(() => repository.update(any()));
  });
}
