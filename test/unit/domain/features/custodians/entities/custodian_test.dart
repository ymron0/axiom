import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:test/test.dart';

void main() {
  group('Custodian', () {
    test('creates a custodian with generated identity and audit metadata', () {
      final timestamp = DateTime.parse('2026-09-12T10:30:00+02:00');

      final custodian = Custodian.create(
        name: '  Main Bank  ',
        kind: CustodianKind.bank,
        icon: EntityIcon.accountBalance,
        color: EntityColor.blue,
        sortOrder: 0,
        clock: FixedClock(timestamp),
      );

      expect(custodian.id.value, isNotEmpty);
      expect(custodian.name, 'Main Bank');
      expect(custodian.entityVersion, 1);
      expect(custodian.createdAt, timestamp.toUtc());
      expect(custodian.modifiedAt, same(custodian.createdAt));
    });

    test('creates a custodian with the default clock when none is provided', () {
      final custodian = Custodian.create(
        name: 'Main Bank',
        kind: CustodianKind.bank,
        icon: EntityIcon.accountBalance,
        color: EntityColor.blue,
        sortOrder: 0,
      );

      expect(custodian.createdAt, isNotNull);
      expect(custodian.modifiedAt, custodian.createdAt);
    });

    test('accepts the minimum sort order', () {
      expect(_createCustodian(sortOrder: 0).sortOrder, 0);
    });

    test('rejects blank names and negative sort order', () {
      expect(
        () => _createCustodian(name: '  '),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'name')),
      );
      expect(
        () => _createCustodian(sortOrder: -1),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'sortOrder'),
        ),
      );
    });

    test('rejects invalid audit metadata', () {
      final createdAt = DateTime.utc(2026, 9, 12);
      expect(
        () => _createCustodian(entityVersion: 0),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'entityVersion'),
        ),
      );
      expect(
        () => _createCustodian(
          createdAt: createdAt,
          modifiedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'modifiedAt'),
        ),
      );
    });

    test('compares equivalent custodians by mapped values', () {
      final first = _createCustodian();
      final equivalent = _createCustodian();
      final different = _createCustodian(
        id: CustodianId.fromString('custodian-2'),
      );

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });
  });
}

Custodian _createCustodian({
  CustodianId? id,
  String name = 'Main Bank',
  int sortOrder = 0,
  int entityVersion = 1,
  DateTime? createdAt,
  DateTime? modifiedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 12);
  return Custodian(
    id: id ?? CustodianId.fromString('custodian-1'),
    name: name,
    kind: CustodianKind.bank,
    icon: EntityIcon.accountBalance,
    color: EntityColor.blue,
    sortOrder: sortOrder,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    entityVersion: entityVersion,
  );
}
