import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'balance_snapshot_subject.mapper.dart';

/// Identifies the domain subject represented by a balance snapshot.
///
/// Balance snapshots are supported exclusively for:
///
/// - accounts;
/// - custodians; and
/// - jars.
///
/// Categories and budgets are deliberately excluded. Their historical state
/// remains transaction-derived and is not represented by balance snapshots.
///
/// ## Typed identity
///
/// Exactly one typed identifier is present.
///
/// Keeping concrete [AccountId], [CustodianId], and [JarId] values prevents
/// unrelated domain identifiers from being used as snapshot subjects.
///
/// ## Persistence
///
/// [BalanceSnapshotSubject] has no independent generated identity. Together
/// with a snapshot date, the subject forms the natural identity of a daily
/// balance snapshot.
///
/// ## Contract
///
/// Prefer [account], [custodian], or [jar] when constructing a new subject.
///
/// The primary constructor supports persistence rehydration and rejects values
/// containing either no subject identity or more than one subject identity.
@MappableClass()
final class BalanceSnapshotSubject with BalanceSnapshotSubjectMappable {
  /// Account identity when this subject represents an account.
  final AccountId? accountId;

  /// Custodian identity when this subject represents a custodian.
  final CustodianId? custodianId;

  /// Jar identity when this subject represents a jar.
  final JarId? jarId;

  /// Creates a persisted balance snapshot subject.
  ///
  /// Exactly one of [accountId], [custodianId], or [jarId] must be present.
  ///
  /// Throws an [ArgumentError] when that invariant is violated.
  @MappableConstructor()
  BalanceSnapshotSubject({this.accountId, this.custodianId, this.jarId}) {
    var subjectCount = 0;

    if (accountId != null) {
      subjectCount++;
    }

    if (custodianId != null) {
      subjectCount++;
    }

    if (jarId != null) {
      subjectCount++;
    }

    if (subjectCount != 1) {
      throw ArgumentError(
        'A balance snapshot subject must identify exactly one account, '
        'custodian, or jar.',
      );
    }
  }

  /// Creates a subject identifying [accountId].
  factory BalanceSnapshotSubject.account(AccountId accountId) {
    return BalanceSnapshotSubject(accountId: accountId);
  }

  /// Creates a subject identifying [custodianId].
  factory BalanceSnapshotSubject.custodian(CustodianId custodianId) {
    return BalanceSnapshotSubject(custodianId: custodianId);
  }

  /// Creates a subject identifying [jarId].
  factory BalanceSnapshotSubject.jar(JarId jarId) {
    return BalanceSnapshotSubject(jarId: jarId);
  }

  /// Returns the typed identifier represented by this subject.
  ///
  /// Callers requiring the concrete identifier type should use [accountId],
  /// [custodianId], or [jarId].
  UniqueId get id {
    final account = accountId;

    if (account != null) {
      return account;
    }

    final custodian = custodianId;

    if (custodian != null) {
      return custodian;
    }

    return jarId!;
  }

  /// Whether this subject represents an account.
  bool get isAccount => accountId != null;

  /// Whether this subject represents a custodian.
  bool get isCustodian => custodianId != null;

  /// Whether this subject represents a jar.
  bool get isJar => jarId != null;
}
