import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:test/test.dart';

void main() {
  group('Account', () {
    test('creates an account with generated identity and audit metadata', () {
      final timestamp = DateTime.parse('2026-09-12T10:30:00+02:00');

      final account = Account.create(
        name: '  Checking  ',
        custodianId: CustodianId.fromString('custodian-1'),
        denominationAssetId: AssetId.fromString('asset-eur'),
        kind: AccountKind.checking,
        reference: '  1234  ',
        icon: EntityIcon.accountBalance,
        color: EntityColor.blue,
        sortOrder: 0,
        clock: FixedClock(timestamp),
      );

      expect(account.id.value, isNotEmpty);
      expect(account.name, 'Checking');
      expect(account.reference, '1234');
      expect(account.entityVersion, 1);
      expect(account.createdAt, timestamp.toUtc());
      expect(account.modifiedAt, same(account.createdAt));
    });

    test('creates an account with the default clock when none is provided', () {
      final account = Account.create(
        name: 'Checking',
        custodianId: CustodianId.fromString('custodian-1'),
        denominationAssetId: AssetId.fromString('asset-eur'),
        kind: AccountKind.checking,
        icon: EntityIcon.accountBalance,
        color: EntityColor.blue,
        sortOrder: 0,
      );

      expect(account.createdAt, isNotNull);
      expect(account.modifiedAt, account.createdAt);
    });

    test('accepts the minimum sort order and omitted reference', () {
      final account = _createAccount(sortOrder: 0);

      expect(account.sortOrder, 0);
      expect(account.reference, isNull);
    });

    test('rejects blank name and reference', () {
      expect(
        () => _createAccount(name: '  '),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'name')),
      );
      expect(
        () => _createAccount(reference: '  '),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'reference'),
        ),
      );
    });

    test('rejects negative sort order', () {
      expect(
        () => _createAccount(sortOrder: -1),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'sortOrder')
              .having((e) => e.invalidValue, 'invalidValue', -1),
        ),
      );
    });

    test('rejects invalid audit metadata', () {
      final createdAt = DateTime.utc(2026, 9, 12);
      expect(
        () => _createAccount(entityVersion: 0),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'entityVersion'),
        ),
      );
      expect(
        () => _createAccount(
          createdAt: createdAt,
          modifiedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'modifiedAt'),
        ),
      );
    });

    test('compares equivalent accounts by mapped values', () {
      final first = _createAccount();
      final equivalent = _createAccount();
      final different = _createAccount(id: AccountId.fromString('account-2'));

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });
  });
}

Account _createAccount({
  AccountId? id,
  String name = 'Checking',
  String? reference,
  int sortOrder = 0,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 12);
  return Account(
    id: id ?? AccountId.fromString('account-1'),
    name: name,
    custodianId: CustodianId.fromString('custodian-1'),
    denominationAssetId: AssetId.fromString('asset-eur'),
    kind: AccountKind.checking,
    reference: reference,
    icon: EntityIcon.accountBalance,
    color: EntityColor.blue,
    sortOrder: sortOrder,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    entityVersion: entityVersion,
  );
}
