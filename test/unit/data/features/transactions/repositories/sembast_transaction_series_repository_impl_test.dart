@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_archived_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_archived_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_series_repository_impl.dart';
import 'package:decimal/decimal.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late TransactionSeriesRepository repository;

  final archivedAt = DateTime.utc(2026, 2, 1);
  final unarchivedAt = DateTime.utc(2026, 3, 1);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastTransactionSeriesRepositoryImpl(database: database);
  });

  group('SembastTransactionSeriesRepositoryImpl', () {
    group('create', () {
      test('persists an active transaction series', () async {
        // Given
        final series = _series(id: 'create', description: 'Monthly rent');

        // When
        final result = await repository.create(series);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(series.id)).valueOrNull;

        expect(stored?.id, series.id);
        expect(stored?.template.description, 'Monthly rent');
      });

      test('returns typed failures for invalid create states', () async {
        // Given
        final existing = _series(id: 'existing');
        await repository.create(existing);

        final archived = _series(id: 'archived-create', archivedAt: archivedAt);

        final deleted = _series(
          id: 'deleted-create',
          deletedAt: DateTime.utc(2026, 2, 2),
        );

        // When
        final duplicateResult = await repository.create(
          _series(id: existing.id.value),
        );

        final archivedResult = await repository.create(archived);
        final deletedResult = await repository.create(deleted);

        // Then
        expect(
          duplicateResult.failureOrNull,
          isA<TransactionSeriesAlreadyExistsFailure>(),
        );
        expect(
          archivedResult.failureOrNull,
          isA<TransactionSeriesAlreadyArchivedFailure>(),
        );
        expect(
          deletedResult.failureOrNull,
          isA<TransactionSeriesAlreadyDeletedFailure>(),
        );
      });
    });

    group('queries', () {
      test('returns all persisted series in an immutable list', () async {
        // Given
        final first = _series(id: 'all-first');
        final second = _series(id: 'all-second');

        await repository.create(first);
        await repository.create(second);

        // When
        final result = await repository.getAll();
        final series = result.valueOrNull!;

        // Then
        expect(
          series.map((item) => item.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => series.clear(), throwsUnsupportedError);
      });

      test('returns successful null when an ID is missing', () async {
        // When
        final result = await repository.getById(
          TransactionSeriesId.fromString('missing'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('separates active and archived series', () async {
        // Given
        final active = _series(id: 'active');
        final archived = _series(id: 'archived');

        await repository.create(active);
        await repository.create(archived);
        await repository.archive(archived.id, archivedAt);

        // When
        final activeResults = (await repository.getActive()).valueOrNull!;
        final archivedResults = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(activeResults.map((item) => item.id), [active.id]);
        expect(archivedResults.map((item) => item.id), [archived.id]);

        expect(() => activeResults.clear(), throwsUnsupportedError);
        expect(() => archivedResults.clear(), throwsUnsupportedError);
      });
    });

    group('reference queries', () {
      test(
        'includes normal and exception replacement templates for archived series',
        () async {
          // Given
          final defaultTemplate = _template(
            merchantId: 'merchant-default',
            accountId: 'account-default',
            categoryId: 'category-default',
            jarId: 'jar-default',
          );

          final replacementTemplate = _template(
            merchantId: 'merchant-replacement',
            accountId: 'account-replacement',
            categoryId: 'category-replacement',
            jarId: 'jar-replacement',
          );

          final series = _series(
            id: 'references',
            template: defaultTemplate,
            exceptions: [
              RecurrenceException.replace(
                scheduledOn: CalendarDate(2026, 2, 1),
                replacementTemplate: replacementTemplate,
              ),
            ],
          );

          await repository.create(series);
          await repository.archive(series.id, archivedAt);

          // When / Then
          expect(
            (await repository.existsByAccountId(
              AccountId.fromString('account-default'),
            )).valueOrNull,
            isTrue,
          );
          expect(
            (await repository.existsByAccountId(
              AccountId.fromString('account-replacement'),
            )).valueOrNull,
            isTrue,
          );

          expect(
            (await repository.existsByMerchantId(
              MerchantId.fromString('merchant-default'),
            )).valueOrNull,
            isTrue,
          );
          expect(
            (await repository.existsByMerchantId(
              MerchantId.fromString('merchant-replacement'),
            )).valueOrNull,
            isTrue,
          );

          expect(
            (await repository.existsByCategoryId(
              CategoryId.fromString('category-default'),
            )).valueOrNull,
            isTrue,
          );
          expect(
            (await repository.existsByCategoryId(
              CategoryId.fromString('category-replacement'),
            )).valueOrNull,
            isTrue,
          );

          expect(
            (await repository.existsByJarId(
              JarId.fromString('jar-default'),
            )).valueOrNull,
            isTrue,
          );
          expect(
            (await repository.existsByJarId(
              JarId.fromString('jar-replacement'),
            )).valueOrNull,
            isTrue,
          );

          expect(
            (await repository.existsByAccountId(
              AccountId.fromString('account-unrelated'),
            )).valueOrNull,
            isFalse,
          );
          expect(
            (await repository.existsByMerchantId(
              MerchantId.fromString('merchant-unrelated'),
            )).valueOrNull,
            isFalse,
          );
          expect(
            (await repository.existsByCategoryId(
              CategoryId.fromString('category-unrelated'),
            )).valueOrNull,
            isFalse,
          );
          expect(
            (await repository.existsByJarId(
              JarId.fromString('jar-unrelated'),
            )).valueOrNull,
            isFalse,
          );
        },
      );
    });

    group('update', () {
      test('persists the complete replacement snapshot', () async {
        // Given
        final original = _series(id: 'update', description: 'Original');

        await repository.create(original);

        final replacement = _series(
          id: original.id.value,
          description: 'Updated',
          modifiedAt: DateTime.utc(2026, 2, 1),
          exceptions: [
            RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
          ],
          entityVersion: original.entityVersion,
        );

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(original.id)).valueOrNull!;

        expect(stored.template.description, 'Updated');
        expect(stored.exceptions, hasLength(1));
        expect(stored.exceptions.single.scheduledOn.toString(), '2026-02-01');
        expect(stored.entityVersion, original.entityVersion);
      });

      test('returns typed failures for missing and deleted series', () async {
        // Given
        final existing = _series(id: 'update-existing');
        await repository.create(existing);

        // When
        final missing = await repository.update(_series(id: 'update-missing'));

        final deleted = await repository.update(
          _series(id: existing.id.value, deletedAt: DateTime.utc(2026, 2, 1)),
        );

        // Then
        expect(missing.failureOrNull, isA<TransactionSeriesNotFoundFailure>());
        expect(
          deleted.failureOrNull,
          isA<TransactionSeriesAlreadyDeletedFailure>(),
        );
      });
    });

    group('archive and unarchive', () {
      test(
        'archives and unarchives a series with supplied timestamps',
        () async {
          // Given
          final series = _series(id: 'archive');
          await repository.create(series);

          // When
          final archiveResult = await repository.archive(series.id, archivedAt);

          // Then
          final archived = archiveResult.valueOrNull!;

          expect(archived.archivedAt, archivedAt);
          expect(archived.modifiedAt, archivedAt);
          expect(archived.entityVersion, series.entityVersion);

          // When
          final unarchiveResult = await repository.unarchive(
            series.id,
            unarchivedAt,
          );

          // Then
          final active = unarchiveResult.valueOrNull!;

          expect(active.archivedAt, isNull);
          expect(active.modifiedAt, unarchivedAt);
          expect(active.entityVersion, series.entityVersion);
        },
      );

      test('returns typed failures for invalid archival transitions', () async {
        // Given
        final series = _series(id: 'transitions');
        await repository.create(series);

        // When
        final missingArchive = await repository.archive(
          TransactionSeriesId.fromString('archive-missing'),
          archivedAt,
        );

        final activeUnarchive = await repository.unarchive(
          series.id,
          unarchivedAt,
        );

        await repository.archive(series.id, archivedAt);

        final duplicateArchive = await repository.archive(
          series.id,
          unarchivedAt,
        );

        // Then
        expect(
          missingArchive.failureOrNull,
          isA<TransactionSeriesNotFoundFailure>(),
        );
        expect(
          activeUnarchive.failureOrNull,
          isA<TransactionSeriesNotArchivedFailure>(),
        );
        expect(
          duplicateArchive.failureOrNull,
          isA<TransactionSeriesAlreadyArchivedFailure>(),
        );
      });

      test('returns not-found when unarchiving a missing series', () async {
        // When
        final result = await repository.unarchive(
          TransactionSeriesId.fromString('missing-unarchive'),
          unarchivedAt,
        );

        // Then
        expect(result.failureOrNull, isA<TransactionSeriesNotFoundFailure>());
      });
    });

    group('delete and restore', () {
      test(
        'physically deletes and restores while preserving archival state',
        () async {
          // Given
          final series = _series(id: 'delete-restore');

          await repository.create(series);
          await repository.archive(series.id, archivedAt);

          // When
          final deleteResult = await repository.delete(series.id);

          // Then
          final deleted = deleteResult.valueOrNull!;

          expect(deleted.deletedAt, isNotNull);
          expect(deleted.archivedAt, archivedAt);
          expect(deleted.modifiedAt, archivedAt);

          expect((await repository.getById(series.id)).valueOrNull, isNull);

          // When
          final restoreResult = await repository.restore(deleted);

          // Then
          expect(restoreResult.isSuccess, isTrue);

          final restored = (await repository.getById(series.id)).valueOrNull!;

          expect(restored.deletedAt, isNull);
          expect(restored.archivedAt, archivedAt);

          final archivedSeries = (await repository.getArchived()).valueOrNull!;

          expect(archivedSeries.map((item) => item.id), contains(series.id));
        },
      );

      test('returns typed delete and restore failures', () async {
        // Given
        final active = _series(id: 'restore-active');
        await repository.create(active);

        final deletedDuplicate = _series(
          id: active.id.value,
          deletedAt: DateTime.utc(2026, 2, 1),
        );

        // When
        final missingDelete = await repository.delete(
          TransactionSeriesId.fromString('delete-missing'),
        );

        final activeRestore = await repository.restore(active);

        final duplicateRestore = await repository.restore(deletedDuplicate);

        // Then
        expect(
          missingDelete.failureOrNull,
          isA<TransactionSeriesNotFoundFailure>(),
        );
        expect(
          activeRestore.failureOrNull,
          isA<TransactionSeriesNotDeletedFailure>(),
        );
        expect(
          duplicateRestore.failureOrNull,
          isA<TransactionSeriesAlreadyExistsFailure>(),
        );
      });
    });

    test('translates malformed persisted series to typed failure', () async {
      // Given
      const id = 'corrupt-series';

      await SembastStores.transactionSeries
          .record(id)
          .put(database, <String, Object?>{});

      // When
      final result = await repository.getById(
        TransactionSeriesId.fromString(id),
      );

      // Then
      expect(result.failureOrNull, isA<TransactionSeriesRepositoryFailure>());
    });

    test(
      'reference query translates corrupt persisted series to typed failure',
      () async {
        // Given
        await SembastStores.transactionSeries
            .record('corrupt-reference')
            .put(database, <String, Object?>{});

        // When
        final result = await repository.existsByAccountId(
          AccountId.fromString('account'),
        );

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionSeriesRepositoryFailure>(),
        );
      },
    );
  });
}

TransactionSeries _series({
  required String id,
  String? description = 'Series',
  TransactionTemplate? template,
  List<RecurrenceException> exceptions = const [],
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return TransactionSeries(
    id: TransactionSeriesId.fromString(id),
    template: template ?? _template(description: description),
    recurrenceRule: RecurrenceRule(
      startsOn: CalendarDate(2026, 1, 1),
      frequency: RecurrenceFrequency.monthly,
    ),
    exceptions: exceptions,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? archivedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}

TransactionTemplate _template({
  String merchantId = 'merchant-default',
  String accountId = 'account-default',
  String? categoryId,
  String? jarId,
  String? description = 'Template',
  String amount = '120',
}) {
  final transactionAmount = AssetAmount(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.parse(amount),
    direction: AssetAmountDirection.outgoing,
  );

  final splits = categoryId == null && jarId == null
      ? <TransactionSplit>[]
      : <TransactionSplit>[
          TransactionSplit(
            transactionAmount: transactionAmount,
            valuationAmount: transactionAmount,
            categoryId: categoryId == null
                ? null
                : CategoryId.fromString(categoryId),
            jarId: jarId == null ? null : JarId.fromString(jarId),
          ),
        ];

  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.fromString(merchantId),
    description: description,
    note: null,
    splits: splits,
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString(accountId),
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: transactionAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}
