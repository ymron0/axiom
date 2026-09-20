@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  late MockGetSettingsUseCase getSettings;
  late MockAssetRepository repository;
  late GetValuationCurrencyService service;
  final currencyId = AssetId.fromString('currency-chf');

  setUpAll(() {
    registerFallbackValue(currencyId);
  });

  setUp(() {
    getSettings = MockGetSettingsUseCase();
    repository = MockAssetRepository();
    service = GetValuationCurrencyService(
      getSettings: getSettings,
      getAssetById: GetAssetByIdUseCase(repository),
    );
  });

  test('returns the configured Currency', () async {
    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: currencyId)),
    );
    final currency = currencyFixture(id: currencyId.value);
    when(
      () => repository.getById(currencyId),
    ).thenAnswer((_) async => Success<Asset?>(currency));

    final result = await service();

    expect(result.valueOrNull, same(currency));
  });

  test('propagates settings failures', () async {
    const failure = SettingsNotInitializedFailure(message: 'settings failed');
    when(() => getSettings()).thenAnswer((_) async => failure);

    final result = await service();

    expect(result.failureOrNull, same(failure));
    verifyNever(() => repository.getById(any()));
  });

  test('returns not initialized when settings are absent', () async {
    when(() => getSettings()).thenAnswer((_) async => const Success(null));

    final result = await service();

    expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());
  });

  test('returns asset-not-found when the configured asset is absent', () async {
    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: currencyId)),
    );
    when(
      () => repository.getById(currencyId),
    ).thenAnswer((_) async => const Success<Asset?>(null));

    final result = await service();

    expect(result.failureOrNull, isA<AssetNotFoundFailure>());
    expect(result.failureOrNull?.message, contains(currencyId.value));
  });

  test('rejects a configured non-currency asset', () async {
    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: currencyId)),
    );
    final crypto = cryptoAssetFixture(id: currencyId.value);
    when(
      () => repository.getById(currencyId),
    ).thenAnswer((_) async => Success<Asset?>(crypto));

    final result = await service();

    expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
  });
}
