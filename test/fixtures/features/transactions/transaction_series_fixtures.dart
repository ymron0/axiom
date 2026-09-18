import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';

import 'transaction_fixtures.dart';

/// Creates a valid transaction-series snapshot for tests.
TransactionSeries transactionSeriesFixture({
  required String id,
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
}) {
  final transaction = transactionFixture(id: 'series-template-source');
  final createdAt = DateTime.utc(2026, 1, 1);

  final template = TransactionTemplate(
    kind: transaction.kind,
    merchantId: transaction.merchantId,
    description: transaction.description,
    note: transaction.note,
    splits: transaction.splits,
    ledgerEntries: transaction.ledgerEntries,
  );

  return TransactionSeries(
    id: TransactionSeriesId.fromString(id),
    template: template,
    recurrenceRule: RecurrenceRule(
      startsOn: CalendarDate(2026, 1, 1),
      frequency: RecurrenceFrequency.monthly,
    ),
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? archivedAt ?? createdAt,
    entityVersion: 1,
  );
}
