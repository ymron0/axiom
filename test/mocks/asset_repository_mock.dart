import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:mocktail/mocktail.dart';

/// A mock asset repository for application-layer tests.
///
/// Example: `final repository = MockAssetRepository();`
class MockAssetRepository extends Mock implements AssetRepository {}
