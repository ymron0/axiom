import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_active_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_deleted_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';
import 'package:fixtures/fixtures.dart';

/// Stores custodians in memory.
final class InMemoryCustodianRepositoryImpl implements CustodianRepository {
  /// Creates a repository seeded with [initialCustodians].
  ///
  /// When omitted, the repository loads the external custodian fixtures. Throws
  /// [ArgumentError] when the seed contains duplicate IDs.
  InMemoryCustodianRepositoryImpl({Iterable<Custodian>? initialCustodians})
    : _custodians = _validatedSeed(
        initialCustodians ??
            custodiansFixtures
                .map<Custodian>(
                  (fixture) => Custodian(
                    id: CustodianId.fromString(fixture.id),
                    name: fixture.name,
                    kind: CustodianKind.values.byName(fixture.kind),
                    logo: switch (fixture.logo) {
                      final logo? => EntityLogo(
                        source: EntityLogoSource.values.byName(logo.source),
                        value: logo.value,
                      ),
                      null => null,
                    },
                    icon: EntityIcon.values.byName(fixture.icon),
                    color: EntityColor.values.byName(fixture.color),
                    sortOrder: fixture.sortOrder,
                    createdAt: fixture.createdAt,
                    modifiedAt: fixture.modifiedAt,
                    entityVersion: fixture.entityVersion,
                  ),
                )
                .toList(),
      );

  final List<Custodian> _custodians;

  static List<Custodian> _validatedSeed(Iterable<Custodian> custodians) {
    final copiedCustodians = custodians.toList();
    final ids = <String>{};

    for (final custodian in copiedCustodians) {
      if (custodian.isDeleted) {
        throw ArgumentError(
          'Deleted custodian cannot be seeded: ${custodian.id.value}',
        );
      }
      if (!ids.add(custodian.id.value)) {
        throw ArgumentError(
          'Custodian ID is duplicated: ${custodian.id.value}',
        );
      }
    }

    return copiedCustodians;
  }

  @override
  Future<Result<void, CustodianFailure>> create(Custodian custodian) async {
    if (custodian.isDeleted) {
      return CustodianAlreadyDeletedFailure(
        message: 'Deleted custodian cannot be created: ${custodian.id.value}',
      );
    }
    if (custodian.isArchived) {
      return CustodianAlreadyArchivedFailure(
        message: 'Archived custodian cannot be created: ${custodian.id.value}',
      );
    }
    if (_custodians.any(
      (storedCustodian) => storedCustodian.id == custodian.id,
    )) {
      return CustodianAlreadyExistsFailure(
        message: 'Custodian ID already exists: ${custodian.id.value}',
      );
    }

    _custodians.add(custodian);
    return const Success(null);
  }

  @override
  Future<Result<Custodian, CustodianFailure>> delete(CustodianId id) async {
    final index = _custodians.indexWhere(
      (custodian) => custodian.id == id,
    );
    if (index == -1) {
      return CustodianNotFoundFailure(
        message: 'Custodian ID was not found: ${id.value}',
      );
    }

    final custodian = _custodians[index];
    final deletedCustodian = _withDeletedAt(custodian, createClock().now);
    _custodians.removeAt(index);
    return Success(deletedCustodian);
  }

  @override
  Future<Result<List<Custodian>, CustodianFailure>> getAll() async {
    return Success(List.unmodifiable(_custodians));
  }

  @override
  Future<Result<Custodian?, CustodianFailure>> getById(CustodianId id) async {
    for (final custodian in _custodians) {
      if (custodian.id.value == id.value) {
        return Success(custodian);
      }
    }

    return const Success(null);
  }

  @override
  Future<Result<void, CustodianFailure>> restore(Custodian custodian) async {
    if (!custodian.isDeleted) {
      return CustodianAlreadyActiveFailure(
        message: 'Custodian is already active: ${custodian.id.value}',
      );
    }
    if (_custodians.any(
      (storedCustodian) => storedCustodian.id == custodian.id,
    )) {
      return CustodianAlreadyExistsFailure(
        message: 'Custodian ID already exists: ${custodian.id.value}',
      );
    }

    _custodians.add(_withDeletedAt(custodian, null));
    return const Success(null);
  }

  @override
  Future<Result<List<Custodian>, CustodianFailure>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    final matches = _custodians
        .where(
          (custodian) => custodian.name.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<void, CustodianFailure>> update(Custodian custodian) async {
    if (custodian.isDeleted) {
      return CustodianAlreadyDeletedFailure(
        message: 'Deleted custodian cannot be updated: ${custodian.id.value}',
      );
    }
    final index = _custodians.indexWhere(
      (storedCustodian) => storedCustodian.id.value == custodian.id.value,
    );
    if (index == -1) {
      return CustodianNotFoundFailure(
        message: 'Custodian ID was not found: ${custodian.id.value}',
      );
    }
    _custodians[index] = custodian;
    return const Success(null);
  }

  static Custodian _withDeletedAt(
    Custodian custodian,
    DateTime? deletedAt,
  ) {
    return Custodian(
      id: custodian.id,
      name: custodian.name,
      kind: custodian.kind,
      logo: custodian.logo,
      icon: custodian.icon,
      color: custodian.color,
      sortOrder: custodian.sortOrder,
      archivedAt: custodian.archivedAt,
      deletedAt: deletedAt,
      createdAt: custodian.createdAt,
      modifiedAt: custodian.modifiedAt,
      entityVersion: custodian.entityVersion,
    );
  }

  @override
  Future<Result<Custodian, CustodianFailure>> archive(
    CustodianId id,
    DateTime archivedAt,
  ) async {
    final index = _custodians.indexWhere((custodian) => custodian.id == id);
    if (index == -1) {
      return CustodianNotFoundFailure(
        message: 'Custodian ID was not found: ${id.value}',
      );
    }

    final custodian = _custodians[index];
    if (custodian.isArchived) {
      return CustodianAlreadyArchivedFailure(
        message: 'Custodian is already archived: ${id.value}',
      );
    }

    final archivedCustodian = _withArchivedAt(
      custodian,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );
    _custodians[index] = archivedCustodian;

    return Success(archivedCustodian);
  }

  @override
  Future<Result<List<Custodian>, CustodianFailure>> getActive() async {
    final matches = _custodians
        .where((custodian) => !custodian.isArchived)
        .toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<List<Custodian>, CustodianFailure>> getArchived() async {
    final matches = _custodians
        .where((custodian) => custodian.isArchived)
        .toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<Custodian, CustodianFailure>> unarchive(
    CustodianId id,
    DateTime modifiedAt,
  ) async {
    final index = _custodians.indexWhere((custodian) => custodian.id == id);
    if (index == -1) {
      return CustodianNotFoundFailure(
        message: 'Custodian ID was not found: ${id.value}',
      );
    }

    final custodian = _custodians[index];
    if (!custodian.isArchived) {
      return CustodianNotArchivedFailure(
        message: 'Custodian is not archived: ${id.value}',
      );
    }

    final unarchivedCustodian = _withArchivedAt(
      custodian,
      archivedAt: null,
      modifiedAt: modifiedAt,
    );
    _custodians[index] = unarchivedCustodian;

    return Success(unarchivedCustodian);
  }

  static Custodian _withArchivedAt(
    Custodian custodian, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return Custodian(
      id: custodian.id,
      name: custodian.name,
      kind: custodian.kind,
      logo: custodian.logo,
      icon: custodian.icon,
      color: custodian.color,
      sortOrder: custodian.sortOrder,
      archivedAt: archivedAt,
      deletedAt: custodian.deletedAt,
      createdAt: custodian.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: custodian.entityVersion,
    );
  }
}
