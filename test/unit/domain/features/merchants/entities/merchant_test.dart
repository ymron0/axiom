import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:test/test.dart';

void main() {
  group('Merchant', () {
    test('creates a merchant with generated identity and audit metadata', () {
      final timestamp = DateTime.parse('2026-09-12T10:30:00+02:00');

      final merchant = Merchant.create(
        name: '  Grocery Store  ',
        clock: FixedClock(timestamp),
      );

      expect(merchant.id.value, isNotEmpty);
      expect(merchant.name, 'Grocery Store');
      expect(merchant.entityVersion, 1);
      expect(merchant.createdAt, timestamp.toUtc());
      expect(merchant.modifiedAt, same(merchant.createdAt));
      expect(merchant.deletedAt, isNull);
      expect(merchant.isDeleted, isFalse);
    });

    test('creates a merchant with the default clock when none is provided', () {
      final merchant = Merchant.create(name: 'Grocery Store');

      expect(merchant.createdAt, isNotNull);
      expect(merchant.modifiedAt, merchant.createdAt);
    });

    test('preserves a deletion timestamp and reports the merchant deleted', () {
      final deletedAt = DateTime.utc(2026, 9, 13);
      final merchant = _createMerchant(deletedAt: deletedAt);

      expect(merchant.deletedAt, same(deletedAt));
      expect(merchant.isDeleted, isTrue);
    });

    test('rejects deletion before creation', () {
      final deletedAt = DateTime.utc(2026, 9, 11);

      expect(
        () => _createMerchant(deletedAt: deletedAt),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'deletedAt')
              .having((e) => e.invalidValue, 'invalidValue', deletedAt),
        ),
      );
    });

    test('rejects invalid audit metadata', () {
      final createdAt = DateTime.utc(2026, 9, 12);
      expect(
        () => _createMerchant(entityVersion: 0),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'entityVersion'),
        ),
      );
      expect(
        () => _createMerchant(
          createdAt: createdAt,
          modifiedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'modifiedAt'),
        ),
      );
    });

    test('compares equivalent merchants by mapped values', () {
      final first = _createMerchant();
      final equivalent = _createMerchant();
      final different = _createMerchant(
        id: MerchantId.fromString('merchant-2'),
      );

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });
  });
}

Merchant _createMerchant({
  MerchantId? id,
  String name = 'Grocery Store',
  DateTime? deletedAt,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 12);
  return Merchant(
    id: id ?? MerchantId.fromString('merchant-1'),
    name: name,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    deletedAt: deletedAt,
    entityVersion: entityVersion,
  );
}
