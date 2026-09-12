import 'package:axiom/src/features/rates/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/features/rates/di/canonical_bridge_asset_id_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'resolve_conversion_rate_service_provider.g.dart';

/// Provides the service that resolves conversion rates between assets.
@riverpod
ResolveConversionRateService resolveConversionRateService(Ref ref) {
  return ResolveConversionRateService(
    repository: ref.watch(rateRepositoryProvider),
    canonicalBridgeAssetId: ref.watch(canonicalBridgeAssetIdProvider),
    rateConversion: const RateConversionService(),
  );
}
