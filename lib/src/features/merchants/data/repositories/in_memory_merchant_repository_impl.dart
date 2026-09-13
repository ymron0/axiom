import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_active_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_deleted_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:fixtures/fixtures.dart';

/// Stores merchants in memory.
final class InMemoryMerchantRepositoryImpl implements MerchantRepository {
  /// Creates a repository seeded with [initialMerchants].
  ///
  /// When omitted, the repository loads the active external merchant fixtures.
  /// Throws [ArgumentError] when the seed contains deleted merchants or
  /// duplicate IDs.
  InMemoryMerchantRepositoryImpl({Iterable<Merchant>? initialMerchants})
    : _merchants = _validatedSeed(
        initialMerchants ??
            merchantsFixtures
                .where((fixture) => fixture.deletedAt == null)
                .map<Merchant>(
                  (fixture) => Merchant(
                    id: MerchantId.fromString(fixture.id),
                    name: fixture.name,
                    createdAt: fixture.createdAt,
                    modifiedAt: fixture.modifiedAt,
                    deletedAt: fixture.deletedAt,
                    entityVersion: fixture.entityVersion,
                  ),
                )
                .toList(),
      );

  final List<Merchant> _merchants;

  static List<Merchant> _validatedSeed(Iterable<Merchant> merchants) {
    final copiedMerchants = merchants.toList();
    final ids = <String>{};

    for (final merchant in copiedMerchants) {
      if (merchant.isDeleted) {
        throw ArgumentError(
          'Deleted merchant cannot be seeded: ${merchant.id.value}',
        );
      }
      if (!ids.add(merchant.id.value)) {
        throw ArgumentError('Merchant ID is duplicated: ${merchant.id.value}');
      }
    }

    return copiedMerchants;
  }

  @override
  Future<Result<void, MerchantFailure>> create(Merchant merchant) async {
    if (merchant.isDeleted) {
      return MerchantAlreadyDeletedFailure(
        message: 'Deleted merchant cannot be created: ${merchant.id.value}',
      );
    }
    if (_merchants.any((storedMerchant) => storedMerchant.id == merchant.id)) {
      return MerchantAlreadyExistsFailure(
        message: 'Merchant ID already exists: ${merchant.id.value}',
      );
    }

    _merchants.add(merchant);
    return const Success(null);
  }

  @override
  Future<Result<Merchant, MerchantFailure>> delete(MerchantId id) async {
    final index = _merchants.indexWhere((merchant) => merchant.id == id);
    if (index == -1) {
      return MerchantNotFoundFailure(
        message: 'Merchant ID was not found: ${id.value}',
      );
    }

    final merchant = _merchants[index];
    final deletedMerchant = _withDeletedAt(merchant, createClock().now);
    _merchants.removeAt(index);
    return Success(deletedMerchant);
  }

  @override
  Future<Result<List<Merchant>, MerchantFailure>> getAll() async {
    return Success(List.unmodifiable(_merchants));
  }

  @override
  Future<Result<Merchant?, MerchantFailure>> getById(MerchantId id) async {
    for (final merchant in _merchants) {
      if (merchant.id == id) {
        return Success(merchant);
      }
    }

    return const Success(null);
  }

  @override
  Future<Result<void, MerchantFailure>> restore(Merchant merchant) async {
    if (!merchant.isDeleted) {
      return MerchantAlreadyActiveFailure(
        message: 'Merchant is already active: ${merchant.id.value}',
      );
    }
    if (_merchants.any((storedMerchant) => storedMerchant.id == merchant.id)) {
      return MerchantAlreadyExistsFailure(
        message: 'Merchant ID already exists: ${merchant.id.value}',
      );
    }

    _merchants.add(_withDeletedAt(merchant, null));
    return const Success(null);
  }

  @override
  Future<Result<List<Merchant>, MerchantFailure>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    final matches = _merchants
        .where(
          (merchant) => merchant.name.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);

    return Success(List.unmodifiable(matches));
  }

  @override
  Future<Result<void, MerchantFailure>> update(Merchant merchant) async {
    if (merchant.isDeleted) {
      return MerchantAlreadyDeletedFailure(
        message: 'Deleted merchant cannot be updated: ${merchant.id.value}',
      );
    }
    final index = _merchants.indexWhere(
      (storedMerchant) => storedMerchant.id == merchant.id,
    );
    if (index == -1) {
      return MerchantNotFoundFailure(
        message: 'Merchant ID was not found: ${merchant.id.value}',
      );
    }

    _merchants[index] = merchant;
    return const Success(null);
  }

  static Merchant _withDeletedAt(Merchant merchant, DateTime? deletedAt) {
    return Merchant(
      id: merchant.id,
      name: merchant.name,
      createdAt: merchant.createdAt,
      modifiedAt: merchant.modifiedAt,
      deletedAt: deletedAt,
      entityVersion: merchant.entityVersion,
    );
  }
}
