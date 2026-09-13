import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:fixtures/fixtures.dart';

/// Stores accounts in memory.
final class InMemoryAccountRepositoryImpl implements AccountRepository {
  /// Creates a repository seeded with [initialAccounts].
  ///
  /// When omitted, the repository loads the external account fixtures. Throws
  /// [ArgumentError] when the seed contains deleted accounts or duplicate IDs.
  InMemoryAccountRepositoryImpl({Iterable<Account>? initialAccounts})
    : _accounts = _validatedSeed(
        initialAccounts ??
            accountsFixtures
                .map<Account>(
                  (fixture) => Account(
                    id: AccountId.fromString(fixture.id),
                    name: fixture.name,
                    custodianId: CustodianId.fromString(fixture.custodianId),
                    denominationAssetId: AssetId.fromString(
                      fixture.denominationAssetId,
                    ),
                    kind: AccountKind.values.byName(fixture.kind),
                    reference: fixture.reference,
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

  final List<Account> _accounts;

  static List<Account> _validatedSeed(Iterable<Account> accounts) {
    final copiedAccounts = accounts.toList();
    final ids = <String>{};

    for (final account in copiedAccounts) {
      if (account.isDeleted) {
        throw ArgumentError(
          'Deleted account cannot be seeded: ${account.id.value}',
        );
      }
      if (!ids.add(account.id.value)) {
        throw ArgumentError('Account ID is duplicated: ${account.id.value}');
      }
    }

    return copiedAccounts;
  }

  @override
  Future<Result<void, AccountFailure>> create(Account account) async {
    if (account.isDeleted) {
      return AccountAlreadyDeletedFailure(
        message: 'Deleted account cannot be created: ${account.id.value}',
      );
    }
    if (_accounts.any((storedAccount) => storedAccount.id == account.id)) {
      return AccountAlreadyExistsFailure(
        message: 'Account ID already exists: ${account.id.value}',
      );
    }

    _accounts.add(account);
    return const Success(null);
  }

  @override
  Future<Result<Account, AccountFailure>> delete(AccountId id) async {
    final index = _accounts.indexWhere((account) => account.id == id);
    if (index == -1) {
      return AccountNotFoundFailure(
        message: 'Account ID was not found: ${id.value}',
      );
    }

    final account = _accounts[index];
    final deletedAccount = _withDeletedAt(account, createClock().now);
    _accounts.removeAt(index);
    return Success(deletedAccount);
  }

  @override
  Future<Result<List<Account>, AccountFailure>> getAll() async {
    return Success(List.unmodifiable(_accounts));
  }

  @override
  Future<Result<List<Account>, AccountFailure>> getByCustodianId(
    CustodianId custodianId,
  ) async {
    final matches = _accounts
        .where((account) => account.custodianId == custodianId)
        .toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<Account?, AccountFailure>> getById(AccountId id) async {
    for (final account in _accounts) {
      if (account.id == id) {
        return Success(account);
      }
    }

    return const Success(null);
  }

  @override
  Future<Result<void, AccountFailure>> restore(Account account) async {
    if (!account.isDeleted) {
      return AccountAlreadyActiveFailure(
        message: 'Account is already active: ${account.id.value}',
      );
    }
    if (_accounts.any((storedAccount) => storedAccount.id == account.id)) {
      return AccountAlreadyExistsFailure(
        message: 'Account ID already exists: ${account.id.value}',
      );
    }

    _accounts.add(_withDeletedAt(account, null));
    return const Success(null);
  }

  @override
  Future<Result<List<Account>, AccountFailure>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    final matches = _accounts
        .where(
          (account) => account.name.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<void, AccountFailure>> update(Account account) async {
    if (account.isDeleted) {
      return AccountAlreadyDeletedFailure(
        message: 'Deleted account cannot be updated: ${account.id.value}',
      );
    }
    final index = _accounts.indexWhere(
      (storedAccount) => storedAccount.id == account.id,
    );
    if (index == -1) {
      return AccountNotFoundFailure(
        message: 'Account ID was not found: ${account.id.value}',
      );
    }

    _accounts[index] = account;
    return const Success(null);
  }

  static Account _withDeletedAt(Account account, DateTime? deletedAt) {
    return Account(
      id: account.id,
      name: account.name,
      custodianId: account.custodianId,
      denominationAssetId: account.denominationAssetId,
      kind: account.kind,
      reference: account.reference,
      logo: account.logo,
      icon: account.icon,
      color: account.color,
      sortOrder: account.sortOrder,
      deletedAt: deletedAt,
      createdAt: account.createdAt,
      modifiedAt: account.modifiedAt,
      entityVersion: account.entityVersion,
    );
  }
}
