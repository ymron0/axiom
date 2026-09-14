@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Jar', () {
    test('creates an active jar with normalized text and deterministic metadata', () {
      final timestamp = DateTime.parse('2026-09-14T10:30:00+02:00');

      final jar = Jar.create(
        name: '  Holiday  ',
        description: '  Summer trip  ',
        kind: JarKind.savingsGoal,
        icon: EntityIcon.savings,
        color: EntityColor.teal,
        sortOrder: 2,
        clock: FixedClock(timestamp),
      );

      expect(jar.id.value, isNotEmpty);
      expect(jar.name, 'Holiday');
      expect(jar.description, 'Summer trip');
      expect(jar.entityVersion, 1);
      expect(jar.createdAt, timestamp.toUtc());
      expect(jar.modifiedAt, jar.createdAt);
      expect(jar.archivedAt, isNull);
      expect(jar.isArchived, isFalse);
      expect(jar.deletedAt, isNull);
      expect(jar.isDeleted, isFalse);
      expect(jar.hasTarget, isFalse);
    });

    test('uses the default clock when none is supplied', () {
      final jar = Jar.create(
        name: 'Holiday',
        kind: JarKind.savingsGoal,
        icon: EntityIcon.savings,
        color: EntityColor.teal,
        sortOrder: 0,
      );

      expect(jar.createdAt, isNotNull);
      expect(jar.modifiedAt, jar.createdAt);
    });

    test('rejects blank names and descriptions, and negative sort orders', () {
      expect(
        () => _jar(name: '  '),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'name')),
      );
      expect(
        () => _jar(description: '  '),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'description'),
        ),
      );
      expect(
        () => _jar(sortOrder: -1),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'sortOrder')
              .having((error) => error.invalidValue, 'invalidValue', -1),
        ),
      );
    });

    test('rejects archive and deletion timestamps outside the lifecycle', () {
      final createdAt = DateTime.utc(2026, 9, 14, 10);
      final modifiedAt = createdAt.add(const Duration(hours: 2));

      expect(
        () => _jar(
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          archivedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'archivedAt')),
      );
      expect(
        () => _jar(
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          archivedAt: modifiedAt.add(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'archivedAt')),
      );
      expect(
        () => _jar(
          createdAt: createdAt,
          deletedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'deletedAt')),
      );
      expect(
        () => _jar(
          createdAt: createdAt,
          modifiedAt: createdAt.add(const Duration(hours: 1)),
          archivedAt: createdAt.add(const Duration(hours: 1)),
          deletedAt: createdAt.add(const Duration(minutes: 30)),
        ),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'deletedAt')),
      );
    });

    test('accepts archive and deletion timestamps within its lifecycle', () {
      final createdAt = DateTime.utc(2026, 9, 14, 10);
      final archivedAt = createdAt.add(const Duration(hours: 1));
      final deletedAt = createdAt.add(const Duration(hours: 2));
      final jar = _jar(
        createdAt: createdAt,
        modifiedAt: deletedAt,
        archivedAt: archivedAt,
        deletedAt: deletedAt,
      );

      expect(jar.archivedAt, archivedAt);
      expect(jar.isArchived, isTrue);
      expect(jar.deletedAt, deletedAt);
      expect(jar.isDeleted, isTrue);
    });

    test('rejects invalid inherited audit metadata', () {
      final createdAt = DateTime.utc(2026, 9, 14);

      expect(
        () => _jar(entityVersion: 0),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'entityVersion'),
        ),
      );
      expect(
        () => _jar(
          createdAt: createdAt,
          modifiedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'modifiedAt')),
      );
    });

    test('accepts adjacent target histories in any input order', () {
      final historical = _target(
        effectiveFrom: CalendarDate(2026, 1, 1),
        effectiveUntil: CalendarDate(2026, 4, 1),
      );
      final current = _target(effectiveFrom: CalendarDate(2026, 4, 1));

      final jar = _jar(targets: [current, historical]);

      expect(jar.targets, [current, historical]);
      expect(jar.hasTarget, isTrue);
    });

    test('defensively copies targets and exposes them as unmodifiable', () {
      final suppliedTargets = [_target()];
      final jar = _jar(targets: suppliedTargets);

      suppliedTargets.clear();

      expect(jar.targets, hasLength(1));
      expect(() => jar.targets.add(_target()), throwsUnsupportedError);
    });

    test('rejects target histories with different currencies', () {
      expect(
        () => _jar(
          targets: [
            _target(assetId: AssetId.fromString('asset-chf')),
            _target(assetId: AssetId.fromString('asset-usd')),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects overlapping and indefinite target histories', () {
      final first = _target(
        effectiveFrom: CalendarDate(2026, 1, 1),
        effectiveUntil: CalendarDate(2026, 4, 1),
      );

      expect(
        () => _jar(
          targets: [
            first,
            _target(
              effectiveFrom: CalendarDate(2026, 3, 1),
              effectiveUntil: CalendarDate(2026, 5, 1),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => _jar(
          targets: [
            _target(effectiveFrom: CalendarDate(2026, 1, 1)),
            _target(effectiveFrom: CalendarDate(2026, 4, 1)),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns the target effective on a date', () {
      final historical = _target(
        effectiveFrom: CalendarDate(2026, 1, 1),
        effectiveUntil: CalendarDate(2026, 4, 1),
      );
      final current = _target(effectiveFrom: CalendarDate(2026, 4, 1));
      final jar = _jar(targets: [historical, current]);

      expect(jar.targetAt(CalendarDate(2025, 12, 31)), isNull);
      expect(jar.targetAt(CalendarDate(2026, 1, 1)), same(historical));
      expect(jar.targetAt(CalendarDate(2026, 3, 31)), same(historical));
      expect(jar.targetAt(CalendarDate(2026, 4, 1)), same(current));
    });
  });
}

Jar _jar({
  JarId? id,
  String name = 'Holiday',
  String? description,
  List<JarTarget> targets = const [],
  int sortOrder = 0,
  DateTime? createdAt,
  DateTime? modifiedAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
  int entityVersion = 1,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 14);
  return Jar(
    id: id ?? JarId.fromString('jar-1'),
    name: name,
    description: description,
    kind: JarKind.savingsGoal,
    targets: targets,
    icon: EntityIcon.savings,
    color: EntityColor.teal,
    sortOrder: sortOrder,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    entityVersion: entityVersion,
  );
}

JarTarget _target({
  AssetId? assetId,
  CalendarDate? effectiveFrom,
  CalendarDate? effectiveUntil,
}) {
  return JarTarget(
    amount: AssetAmount(
      assetId: assetId ?? AssetId.fromString('asset-chf'),
      amount: Decimal.parse('100'),
      direction: AssetAmountDirection.incoming,
    ),
    effectiveFrom: effectiveFrom ?? CalendarDate(2026, 1, 1),
    effectiveUntil: effectiveUntil,
  );
}
