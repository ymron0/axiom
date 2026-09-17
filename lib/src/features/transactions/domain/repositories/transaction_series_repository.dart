// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';

/// Domain-facing contract for storing and retrieving [TransactionSeries]
/// entities.
///
/// A transaction series defines recurring transaction behavior but does not own
/// transactions generated from that definition.
///
/// Generated occurrences are persisted independently through the transaction
/// repository as ordinary transactions.
///
/// ## Persistence semantics
///
/// Persisted transaction series may be either active or archived.
///
/// Deleted series are absent from persistence.
///
/// [getAll] therefore returns both active and archived series, but never
/// physically deleted series.
///
/// ## Archival
///
/// Archival is reversible.
///
/// An archived series remains persisted and retains its:
///
/// - recurrence rule;
/// - transaction template;
/// - recurrence exceptions;
/// - amount-based termination configuration; and
/// - historical domain meaning.
///
/// Archived series must not normally participate in future occurrence
/// generation.
///
/// [getActive] therefore provides the primary repository operation for workflows
/// that need to discover series eligible for future generation.
///
/// ## Deletion
///
/// Deletion is physical.
///
/// The repository does not retain deleted transaction-series snapshots.
///
/// A caller that requires undo or restoration must retain the deleted
/// [TransactionSeries] returned by [delete] and later pass that snapshot to
/// [restore].
///
/// Deleting a transaction series has no effect on transactions that were
/// previously generated from the series.
///
/// Those transactions remain ordinary independent transactions.
///
/// ## Generated transactions
///
/// This repository stores only [TransactionSeries] entities.
///
/// It does not:
///
/// - store generated transactions;
/// - associate generated `TransactionId` values with series;
/// - maintain generated-occurrence history;
/// - calculate future occurrence dates;
/// - evaluate cumulative recurrence amounts; or
/// - instantiate transaction templates.
///
/// Those responsibilities belong to their respective transaction repositories,
/// domain objects, and application workflows.
///
/// ## Reference semantics
///
/// A series may reference other domain entities through both:
///
/// - its normal transaction template; and
/// - replacement templates contained in recurrence exceptions.
///
/// Reference-existence operations therefore inspect the entire persisted series
/// definition, including exception replacement templates.
///
/// Both active and archived series count as persisted references.
///
/// This is important because an archived series may later be unarchived. A
/// referenced account, merchant, category, or jar must therefore not be treated
/// as unreferenced merely because the series is currently archived.
///
/// ## Result semantics
///
/// Expected repository failures are returned through
/// [TransactionSeriesFailure].
///
/// Repository implementations must translate persistence-specific exceptions
/// into the appropriate domain failure type rather than exposing database or
/// storage-library exceptions through this interface.
///
/// ## Collection semantics
///
/// Methods returning collections return an empty list when no matching series
/// exist.
///
/// Returned collections must not expose mutable repository-owned state.
///
/// ## Contract
///
/// Implementations must preserve [TransactionSeries.entityVersion].
///
/// The entity version identifies the persisted domain class version; it is not
/// an optimistic-lock revision counter and must not be incremented merely
/// because a snapshot is updated.
abstract interface class TransactionSeriesRepository {
  /// Stores a new active [series].
  ///
  /// The supplied series must represent an active, non-deleted entity.
  ///
  /// A repository implementation must fail when:
  ///
  /// - another persisted series already has [TransactionSeries.id];
  /// - [TransactionSeries.archivedAt] is not `null`; or
  /// - [TransactionSeries.deletedAt] is not `null`.
  ///
  /// Domain invariant validation belongs to [TransactionSeries] itself and is
  /// expected to have completed before this repository operation is invoked.
  Future<Result<void, TransactionSeriesFailure>> create(
    TransactionSeries series,
  );

  /// Returns every persisted transaction series.
  ///
  /// Both active and archived series are included.
  ///
  /// Physically deleted series are absent.
  ///
  /// Returns an empty list when no transaction series exist.
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>> getAll();

  /// Returns all persisted transaction series that are not archived.
  ///
  /// These are the series normally eligible for future occurrence generation.
  ///
  /// This method does not evaluate recurrence end conditions. An active series
  /// may already have reached its date, count, or amount target; determining
  /// that belongs to the occurrence-generation workflow.
  ///
  /// Returns an empty list when no active series exist.
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>>
  getActive();

  /// Returns all persisted transaction series that are archived.
  ///
  /// Archived series remain persisted for historical meaning and may later be
  /// unarchived.
  ///
  /// Returns an empty list when no archived series exist.
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>>
  getArchived();

  /// Returns the persisted transaction series identified by [id].
  ///
  /// Returns `null` when no persisted series has that identity.
  ///
  /// Both active and archived series may be returned.
  Future<Result<TransactionSeries?, TransactionSeriesFailure>> getById(
    TransactionSeriesId id,
  );

  /// Whether any persisted transaction series references [accountId].
  ///
  /// A match exists when [accountId] is referenced by a ledger entry in:
  ///
  /// - the series's default transaction template; or
  /// - any recurrence-exception replacement template.
  ///
  /// Both active and archived series are considered.
  ///
  /// This operation exists primarily to support deletion-safety checks for
  /// accounts. Removing an account while a persisted series still references it
  /// could make future generation or restoration of that series invalid.
  Future<Result<bool, TransactionSeriesFailure>> existsByAccountId(
    AccountId accountId,
  );

  /// Whether any persisted transaction series references [merchantId].
  ///
  /// A match exists when [merchantId] is referenced by:
  ///
  /// - the series's default transaction template; or
  /// - any recurrence-exception replacement template.
  ///
  /// Both active and archived series are considered.
  ///
  /// This operation supports merchant deletion-safety checks independently of
  /// whether any ordinary transaction has already been generated.
  Future<Result<bool, TransactionSeriesFailure>> existsByMerchantId(
    MerchantId merchantId,
  );

  /// Whether any persisted transaction series references [categoryId].
  ///
  /// A match exists when a transaction split in:
  ///
  /// - the series's default transaction template; or
  /// - any recurrence-exception replacement template
  ///
  /// references [categoryId].
  ///
  /// Both active and archived series are considered.
  ///
  /// This operation supports category deletion-safety checks before future
  /// occurrence generation can be made invalid by removal of the category.
  Future<Result<bool, TransactionSeriesFailure>> existsByCategoryId(
    CategoryId categoryId,
  );

  /// Whether any persisted transaction series references [jarId].
  ///
  /// A match exists when a transaction split in:
  ///
  /// - the series's default transaction template; or
  /// - any recurrence-exception replacement template
  ///
  /// references [jarId].
  ///
  /// Both active and archived series are considered.
  ///
  /// This operation supports jar deletion-safety checks independently of
  /// already-generated ordinary transactions.
  Future<Result<bool, TransactionSeriesFailure>> existsByJarId(
    JarId jarId,
  );

  /// Replaces the persisted snapshot of [series].
  ///
  /// The identity represented by [TransactionSeries.id] must already exist.
  ///
  /// The supplied snapshot must not be deleted.
  ///
  /// The repository must preserve [TransactionSeries.entityVersion]. Updating
  /// the persisted snapshot does not increment that value.
  ///
  /// This operation may update recurrence definitions, templates, exceptions,
  /// archival state, or other mutable series configuration represented by the
  /// entity snapshot.
  Future<Result<void, TransactionSeriesFailure>> update(
    TransactionSeries series,
  );

  /// Archives the transaction series identified by [id].
  ///
  /// [archivedAt] becomes both:
  ///
  /// - the series archival timestamp; and
  /// - its new modification timestamp.
  ///
  /// The series remains persisted.
  ///
  /// Archiving prevents normal future occurrence generation but does not alter
  /// the recurrence definition or any transactions that were already generated.
  ///
  /// The operation must fail when:
  ///
  /// - no persisted series exists for [id]; or
  /// - the series is already archived.
  ///
  /// Returns the resulting archived snapshot.
  Future<Result<TransactionSeries, TransactionSeriesFailure>> archive(
    TransactionSeriesId id,
    DateTime archivedAt,
  );

  /// Removes archival state from the transaction series identified by [id].
  ///
  /// [modifiedAt] becomes the series's new modification timestamp.
  ///
  /// Unarchiving makes the series eligible for normal future generation again,
  /// subject to its recurrence end conditions.
  ///
  /// The operation must fail when:
  ///
  /// - no persisted series exists for [id]; or
  /// - the series is not archived.
  ///
  /// Returns the resulting active snapshot.
  Future<Result<TransactionSeries, TransactionSeriesFailure>> unarchive(
    TransactionSeriesId id,
    DateTime modifiedAt,
  );

  /// Physically removes the transaction series identified by [id].
  ///
  /// The removed series is absent from persistence after successful deletion.
  ///
  /// Previously generated transactions are not deleted or modified.
  ///
  /// Returns a caller-owned snapshot representing the removed series with
  /// [TransactionSeries.deletedAt] populated according to the repository's
  /// deletion semantics.
  ///
  /// The repository does not retain this deleted snapshot.
  ///
  /// The operation must fail when no persisted series exists for [id].
  Future<Result<TransactionSeries, TransactionSeriesFailure>> delete(
    TransactionSeriesId id,
  );

  /// Restores the caller-retained deleted [series].
  ///
  /// On success, persistence contains a snapshot with
  /// [TransactionSeries.deletedAt] cleared.
  ///
  /// [TransactionSeries.archivedAt] is preserved. Restoring a series that was
  /// archived before deletion therefore restores it as archived rather than
  /// automatically activating it.
  ///
  /// The operation must fail when:
  ///
  /// - [series] does not represent a deleted snapshot; or
  /// - another persisted series already has the same
  ///   [TransactionSeries.id].
  ///
  /// Restoration does not create, restore, or modify ordinary transactions.
  Future<Result<void, TransactionSeriesFailure>> restore(
    TransactionSeries series,
  );
}