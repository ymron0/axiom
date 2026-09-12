import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account.mapper.dart';

/// A financial account held by a custodian.
///
/// An account represents a distinct financial position whose balance is derived
/// from ledger entries rather than stored directly on the entity.
///
/// Each account belongs to exactly one custodian and is denominated in exactly
/// one asset. The denomination determines the asset used when deriving the
/// account's balance.
///
/// ## Visual identity
///
/// [color] and [icon] provide stable visual identity independently of the
/// presentation framework.
///
/// [logo] is optional. When no logo exists, or when the logo cannot be rendered,
/// [icon] is the fallback visual representation.
///
/// ## Reference
///
/// [reference] is an optional user-facing identifier that helps distinguish
/// accounts with similar names. Examples include the last digits of an IBAN,
/// card number, or another institution-provided account reference.
///
/// It is not intended to contain credentials, authentication information, or
/// other secrets.
///
/// ## Ordering
///
/// [sortOrder] provides deterministic user-defined ordering between accounts.
/// It does not express identity or financial priority.
///
/// ## Balance
///
/// The account deliberately stores no balance. Its balance is derived from the
/// ledger entries associated with [id].
///
/// ## Invariants
///
/// - [name] is trimmed and cannot be blank.
/// - [reference], when present, is trimmed and cannot be blank.
/// - [sortOrder] cannot be negative.
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] is greater than zero, as enforced by [AuditedEntity].
@MappableClass()
final class Account extends AuditedEntity<AccountId> with AccountMappable {
  /// The human-readable account name.
  final String name;

  /// The custodian that holds this account.
  final CustodianId custodianId;

  /// The asset in which this account is denominated.
  final AssetId denominationAssetId;

  /// The semantic kind of account.
  final AccountKind kind;

  /// An optional user-facing account reference.
  ///
  /// This may contain an IBAN or card number.
  final String? reference;

  /// An optional logo associated with this account.
  final EntityLogo? logo;

  /// The fallback icon and semantic icon identity for this account.
  final EntityIcon icon;

  /// The semantic color identity assigned to this account.
  final EntityColor color;

  /// The user-defined ordering position of this account.
  final int sortOrder;

  /// Creates an account.
  ///
  /// Throws an [ArgumentError] when [name] is blank, [reference] is supplied as
  /// blank text, or [sortOrder] is negative.
  @MappableConstructor()
  Account({
    required super.id,
    required String name,
    required this.custodianId,
    required this.denominationAssetId,
    required this.kind,
    String? reference,
    this.logo,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required super.createdAt,
    required super.modifiedAt,
    required super.entityVersion,
  }) : name = normalizeRequiredText(name, 'name'),
       reference = normalizeOptionalText(reference, 'reference') {
    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'Account sort order cannot be negative.',
      );
    }
  }

  /// Creates a new account with generated identity and audit metadata.
  factory Account.create({
    required String name,
    required CustodianId custodianId,
    required AssetId denominationAssetId,
    required AccountKind kind,
    String? reference,
    EntityLogo? logo,
    required EntityIcon icon,
    required EntityColor color,
    required int sortOrder,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Account(
      id: AccountId.generate(),
      name: name,
      custodianId: custodianId,
      denominationAssetId: denominationAssetId,
      kind: kind,
      reference: reference,
      logo: logo,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      modifiedAt: now,
      entityVersion: 1,
    );
  }
}
