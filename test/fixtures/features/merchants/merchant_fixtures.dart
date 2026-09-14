import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';

/// Creates a valid merchant snapshot for tests.
Merchant merchantFixture({
  required String id,
  String name = 'Test Merchant',
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return Merchant(
    id: MerchantId.fromString(id),
    name: name,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    entityVersion: 1,
  );
}
