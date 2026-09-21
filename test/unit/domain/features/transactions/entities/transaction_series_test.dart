@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeries', () {
    group('creation', () {
      test(
        'creates an active series with generated identity and audit metadata',
        () {
          // Given
          final now = DateTime.utc(2026, 9, 17, 12);
          final template = _template('normal');
          final rule = _monthlyRule();

          // When
          final series = TransactionSeries.create(
            template: template,
            recurrenceRule: rule,
            clock: FixedClock(now),
          );

          // Then
          expect(series.id, isA<TransactionSeriesId>());
          expect(series.id.value, isNotEmpty);
          expect(series.template, same(template));
          expect(series.recurrenceRule, same(rule));
          expect(series.exceptions, isEmpty);

          expect(series.createdAt, now);
          expect(series.modifiedAt, now);
          expect(series.entityVersion, 1);

          expect(series.archivedAt, isNull);
          expect(series.deletedAt, isNull);
          expect(series.isArchived, isFalse);
          expect(series.isDeleted, isFalse);
          expect(series.isGenerationEnabled, isTrue);
        },
      );

      test('creates a series with initial recurrence exceptions', () {
        // Given
        final exception = RecurrenceException.skip(
          scheduledOn: CalendarDate(2026, 2, 1),
        );

        // When
        final series = TransactionSeries.create(
          template: _template('normal'),
          recurrenceRule: _monthlyRule(),
          exceptions: [exception],
          clock: FixedClock(DateTime.utc(2026, 1, 1)),
        );

        // Then
        expect(series.exceptions, [exception]);
      });

      test('uses the default clock when none is supplied', () {
        // When
        final series = TransactionSeries.create(
          template: _template('normal'),
          recurrenceRule: _monthlyRule(),
        );

        // Then
        expect(series.createdAt.isUtc, isTrue);
        expect(series.modifiedAt, series.createdAt);
      });
    });

    group('exception collection', () {
      test('defensively copies the supplied exceptions', () {
        // Given
        final exception = RecurrenceException.skip(
          scheduledOn: CalendarDate(2026, 2, 1),
        );

        final source = <RecurrenceException>[exception];

        // When
        final series = _series(exceptions: source);
        source.clear();

        // Then
        expect(series.exceptions, [exception]);
      });

      test('exposes exceptions as an immutable collection', () {
        // Given
        final series = _series(
          exceptions: [
            RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
          ],
        );

        // When
        void mutate() {
          series.exceptions.add(
            RecurrenceException.skip(scheduledOn: CalendarDate(2026, 3, 1)),
          );
        }

        // Then
        expect(mutate, throwsUnsupportedError);
      });

      test('rejects an exception whose scheduled date is not in the rule', () {
        // Given
        final exception = RecurrenceException.skip(
          scheduledOn: CalendarDate(2026, 2, 2),
        );

        // When
        TransactionSeries construct() {
          return _series(exceptions: [exception]);
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'exceptions',
            ),
          ),
        );
      });

      test(
        'rejects an exception beyond the recurrence termination condition',
        () {
          // Given
          final rule = RecurrenceRule(
            startsOn: CalendarDate(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            end: RecurrenceEnd(count: 2),
          );

          final exception = RecurrenceException.skip(
            scheduledOn: CalendarDate(2026, 3, 1),
          );

          // When
          TransactionSeries construct() {
            return _series(recurrenceRule: rule, exceptions: [exception]);
          }

          // Then
          expect(
            construct,
            throwsA(
              isA<ArgumentError>().having(
                (error) => error.name,
                'name',
                'exceptions',
              ),
            ),
          );
        },
      );

      test('rejects multiple exceptions for the same scheduled occurrence', () {
        // Given
        final scheduledOn = CalendarDate(2026, 2, 1);

        final first = RecurrenceException.skip(scheduledOn: scheduledOn);

        final second = RecurrenceException.replace(
          scheduledOn: scheduledOn,
          replacementOn: CalendarDate(2026, 2, 2),
        );

        // When
        TransactionSeries construct() {
          return _series(exceptions: [first, second]);
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'exceptions',
            ),
          ),
        );
      });

      test('finds an exception by original scheduled date', () {
        // Given
        final exception = RecurrenceException.skip(
          scheduledOn: CalendarDate(2026, 2, 1),
        );

        final series = _series(exceptions: [exception]);

        // When
        final result = series.exceptionFor(CalendarDate(2026, 2, 1));

        // Then
        expect(result, same(exception));
      });

      test('returns null when the scheduled date has no exception', () {
        // Given
        final series = _series(
          exceptions: [
            RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
          ],
        );

        // When
        final result = series.exceptionFor(CalendarDate(2026, 3, 1));

        // Then
        expect(result, isNull);
      });

      test('replacement date is not treated as an exception key', () {
        // Given
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementOn: CalendarDate(2026, 2, 5),
        );

        final series = _series(exceptions: [exception]);

        // Then
        expect(series.exceptionFor(CalendarDate(2026, 2, 1)), same(exception));

        expect(series.exceptionFor(CalendarDate(2026, 2, 5)), isNull);
      });
    });

    group('occurrence resolution', () {
      test('resolves a normal occurrence without an exception', () {
        // Given
        final template = _template('normal');

        final series = _series(template: template);

        // When
        final occurrence = series.resolveOccurrenceAt(1);

        // Then
        expect(occurrence, isNotNull);
        expect(occurrence!.date, CalendarDate(2026, 2, 1));
        expect(occurrence.template, same(template));
      });

      test('returns null for a skipped occurrence', () {
        // Given
        final series = _series(
          exceptions: [
            RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
          ],
        );

        // When
        final occurrence = series.resolveOccurrenceAt(1);

        // Then
        expect(occurrence, isNull);
      });

      test('moves an occurrence to its replacement date', () {
        // Given
        final normalTemplate = _template('normal');

        final series = _series(
          template: normalTemplate,
          exceptions: [
            RecurrenceException.replace(
              scheduledOn: CalendarDate(2026, 2, 1),
              replacementOn: CalendarDate(2026, 2, 5),
            ),
          ],
        );

        // When
        final occurrence = series.resolveOccurrenceAt(1);

        // Then
        expect(occurrence, isNotNull);
        expect(occurrence!.date, CalendarDate(2026, 2, 5));
        expect(occurrence.template, same(normalTemplate));
      });

      test(
        'replaces the transaction template without moving the occurrence',
        () {
          // Given
          final normalTemplate = _template('normal');
          final specialTemplate = _template('special');

          final series = _series(
            template: normalTemplate,
            exceptions: [
              RecurrenceException.replace(
                scheduledOn: CalendarDate(2026, 2, 1),
                replacementTemplate: specialTemplate,
              ),
            ],
          );

          // When
          final occurrence = series.resolveOccurrenceAt(1);

          // Then
          expect(occurrence, isNotNull);
          expect(occurrence!.date, CalendarDate(2026, 2, 1));
          expect(occurrence.template, same(specialTemplate));
        },
      );

      test('replaces both the occurrence date and template', () {
        // Given
        final specialTemplate = _template('special');

        final series = _series(
          exceptions: [
            RecurrenceException.replace(
              scheduledOn: CalendarDate(2026, 2, 1),
              replacementOn: CalendarDate(2026, 1, 30),
              replacementTemplate: specialTemplate,
            ),
          ],
        );

        // When
        final occurrence = series.resolveOccurrenceAt(1);

        // Then
        expect(occurrence, isNotNull);
        expect(occurrence!.date, CalendarDate(2026, 1, 30));
        expect(occurrence.template, same(specialTemplate));
      });

      test(
        'allows an explicit replacement outside the recurrence end boundary',
        () {
          // Given
          final rule = RecurrenceRule(
            startsOn: CalendarDate(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            end: RecurrenceEnd(until: CalendarDate(2026, 2, 1)),
          );

          final series = _series(
            recurrenceRule: rule,
            exceptions: [
              RecurrenceException.replace(
                scheduledOn: CalendarDate(2026, 2, 1),
                replacementOn: CalendarDate(2026, 2, 3),
              ),
            ],
          );

          // When
          final occurrence = series.resolveOccurrenceAt(1);

          // Then
          expect(occurrence, isNotNull);
          expect(occurrence!.date, CalendarDate(2026, 2, 3));
        },
      );

      test('returns null when the recurrence itself has ended', () {
        // Given
        final series = _series(
          recurrenceRule: RecurrenceRule(
            startsOn: CalendarDate(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            end: RecurrenceEnd(count: 2),
          ),
        );

        // When
        final occurrence = series.resolveOccurrenceAt(2);

        // Then
        expect(occurrence, isNull);
      });

      test('rejects a negative occurrence index', () {
        // Given
        final series = _series();

        // When
        dynamic resolve() => series.resolveOccurrenceAt(-1);

        // Then
        expect(
          resolve,
          throwsA(
            isA<RangeError>().having((error) => error.name, 'name', 'index'),
          ),
        );
      });
    });

    group('amount termination', () {
      test('exposes the configured amount end', () {
        // Given
        final amountEnd = _amountEnd();
        final series = _series(recurrenceRule: _amountRule(amountEnd));

        // Then
        expect(series.amountEnd, same(amountEnd));
      });

      test('rejects amount termination for transfer series', () {
        // Given
        final template = _template('transfer', kind: TransactionKind.transfer);

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'recurrenceRule',
            message:
                'Amount-based recurrence termination is supported only for '
                'expense and income transaction series.',
          ),
        );
      });

      test('rejects amount termination for balance-correction series', () {
        // Given
        final template = _template(
          'correction',
          kind: TransactionKind.balanceCorrection,
        );

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'recurrenceRule',
            message:
                'Amount-based recurrence termination is supported only for '
                'expense and income transaction series.',
          ),
        );
      });

      test('rejects a normal template without exactly one primary entry', () {
        // Given
        final template = _template('missing primary', ledgerEntries: const []);

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'An amount-target recurrence requires exactly one primary '
                'ledger entry.',
          ),
        );
      });

      test('rejects a normal template with multiple primary entries', () {
        // Given
        final amount = _outgoingAmount('100');
        final template = _template(
          'multiple primaries',
          ledgerEntries: [_entry(amount), _entry(amount)],
        );

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'An amount-target recurrence requires exactly one primary '
                'ledger entry.',
          ),
        );
      });

      test('rejects an unknown normal primary amount', () {
        // Given
        final template = _template(
          'unknown amount',
          primaryAmount: _outgoingAmount('-1'),
        );

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'An amount-target recurrence requires a known primary '
                'transaction amount.',
          ),
        );
      });

      test('rejects a zero normal primary amount', () {
        // Given
        final template = _template(
          'zero amount',
          primaryAmount: _outgoingAmount('0'),
        );

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'The normal transaction template of an amount-target '
                'recurrence must have a primary amount greater than zero.',
          ),
        );
      });

      test('rejects a normal primary amount using another asset', () {
        // Given
        final template = _template(
          'wrong asset',
          primaryAmount: _outgoingAmount(
            '100',
            assetId: AssetId.fromString('asset-eur'),
          ),
        );

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'The primary transaction amount must use the recurrence '
                'target asset.',
          ),
        );
      });

      test('rejects a normal primary amount with another direction', () {
        // Given
        final template = _template(
          'wrong direction',
          primaryAmount: _incomingAmount('100'),
        );

        // When
        TransactionSeries construct() {
          return _series(template: template, recurrenceRule: _amountRule());
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'The primary transaction amount must use the recurrence '
                'target direction.',
          ),
        );
      });

      test('rejects a replacement template with another transaction kind', () {
        // Given
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementTemplate: _template(
            'income replacement',
            kind: TransactionKind.income,
            primaryAmount: _incomingAmount('100'),
          ),
        );

        // When
        TransactionSeries construct() {
          return _series(
            recurrenceRule: _amountRule(),
            exceptions: [exception],
          );
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'exceptions',
            message:
                'An amount-target recurrence replacement template must '
                'preserve the series transaction kind.',
          ),
        );
      });

      test('rejects a replacement template without one primary entry', () {
        // Given
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementTemplate: _template(
            'missing replacement primary',
            ledgerEntries: const [],
          ),
        );

        // When
        TransactionSeries construct() {
          return _series(
            recurrenceRule: _amountRule(),
            exceptions: [exception],
          );
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'An amount-target recurrence requires exactly one primary '
                'ledger entry.',
          ),
        );
      });

      test('rejects an unknown replacement primary amount', () {
        // Given
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementTemplate: _template(
            'unknown replacement amount',
            primaryAmount: _outgoingAmount('-1'),
          ),
        );

        // When
        TransactionSeries construct() {
          return _series(
            recurrenceRule: _amountRule(),
            exceptions: [exception],
          );
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'An amount-target recurrence requires a known primary '
                'transaction amount.',
          ),
        );
      });

      test('rejects a replacement primary amount using another asset', () {
        // Given
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementTemplate: _template(
            'wrong replacement asset',
            primaryAmount: _outgoingAmount(
              '100',
              assetId: AssetId.fromString('asset-eur'),
            ),
          ),
        );

        // When
        TransactionSeries construct() {
          return _series(
            recurrenceRule: _amountRule(),
            exceptions: [exception],
          );
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'The primary transaction amount must use the recurrence '
                'target asset.',
          ),
        );
      });

      test('rejects a replacement primary amount with another direction', () {
        // Given
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementTemplate: _template(
            'wrong replacement direction',
            primaryAmount: _incomingAmount('100'),
          ),
        );

        // When
        TransactionSeries construct() {
          return _series(
            recurrenceRule: _amountRule(),
            exceptions: [exception],
          );
        }

        // Then
        expect(
          construct,
          _argumentError(
            name: 'template',
            message:
                'The primary transaction amount must use the recurrence '
                'target direction.',
          ),
        );
      });

      test('allows a zero replacement primary amount', () {
        // Given
        final replacementTemplate = _template(
          'zero replacement amount',
          primaryAmount: _outgoingAmount('0'),
        );
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 2, 1),
          replacementTemplate: replacementTemplate,
        );

        // When
        final series = _series(
          recurrenceRule: _amountRule(),
          exceptions: [exception],
        );

        // Then
        expect(
          series.amountProgressFor(replacementTemplate).amount,
          Decimal.zero,
        );
      });

      test('throws when amount progress is requested without a target', () {
        // Given
        final series = _series();

        // Then
        expect(
          () => series.amountProgressFor(series.template),
          throwsStateError,
        );
        expect(
          () => series.resolveNextAmount(
            accumulatedAmount: _outgoingAmount('0'),
            occurrenceTemplate: series.template,
          ),
          throwsStateError,
        );
      });

      test('resolves the next amount through the configured target', () {
        // Given
        final series = _series(recurrenceRule: _amountRule());

        // When
        final nextAmount = series.resolveNextAmount(
          accumulatedAmount: _outgoingAmount('250'),
          occurrenceTemplate: series.template,
        );

        // Then
        expect(nextAmount?.assetId, AssetId.fromString('asset-chf'));
        expect(nextAmount?.amount, Decimal.parse('50'));
      });
    });

    group('recurrence definition', () {
      test(
        'definesOccurrenceOn describes the underlying rule before exceptions',
        () {
          // Given
          final series = _series(
            exceptions: [
              RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
            ],
          );

          // Then
          expect(series.definesOccurrenceOn(CalendarDate(2026, 2, 1)), isTrue);

          expect(series.resolveOccurrenceAt(1), isNull);
        },
      );

      test(
        'a moved replacement does not change the underlying recurrence rule',
        () {
          // Given
          final series = _series(
            exceptions: [
              RecurrenceException.replace(
                scheduledOn: CalendarDate(2026, 2, 1),
                replacementOn: CalendarDate(2026, 2, 5),
              ),
            ],
          );

          // Then
          expect(series.definesOccurrenceOn(CalendarDate(2026, 2, 1)), isTrue);

          expect(series.definesOccurrenceOn(CalendarDate(2026, 2, 5)), isFalse);

          expect(series.resolveOccurrenceAt(1)!.date, CalendarDate(2026, 2, 5));
        },
      );
    });

    group('archival', () {
      test('preserves a valid archive timestamp', () {
        // Given
        final archivedAt = DateTime.utc(2026, 2, 1);

        // When
        final series = _series(archivedAt: archivedAt, modifiedAt: archivedAt);

        // Then
        expect(series.archivedAt, archivedAt);
        expect(series.isArchived, isTrue);
        expect(series.isGenerationEnabled, isFalse);
      });

      test('rejects archive time before creation', () {
        // Given
        final archivedAt = DateTime.utc(2025, 12, 31);

        // When
        TransactionSeries construct() {
          return _series(archivedAt: archivedAt);
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'archivedAt',
            ),
          ),
        );
      });

      test('rejects archive time after modification', () {
        // Given
        final archivedAt = DateTime.utc(2026, 3, 1);

        // When
        TransactionSeries construct() {
          return _series(
            archivedAt: archivedAt,
            modifiedAt: DateTime.utc(2026, 2, 1),
          );
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'archivedAt',
            ),
          ),
        );
      });

      test('archival does not change recurrence or exception resolution', () {
        // Given
        final archivedAt = DateTime.utc(2026, 2, 1);

        final series = _series(
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
          exceptions: [
            RecurrenceException.replace(
              scheduledOn: CalendarDate(2026, 2, 1),
              replacementOn: CalendarDate(2026, 2, 5),
            ),
          ],
        );

        // Then
        expect(series.isGenerationEnabled, isFalse);

        expect(series.definesOccurrenceOn(CalendarDate(2026, 2, 1)), isTrue);

        expect(series.resolveOccurrenceAt(1)!.date, CalendarDate(2026, 2, 5));
      });
    });

    group('deletion', () {
      test('preserves a valid deletion timestamp', () {
        // Given
        final deletedAt = DateTime.utc(2026, 2, 1);

        // When
        final series = _series(deletedAt: deletedAt, modifiedAt: deletedAt);

        // Then
        expect(series.deletedAt, deletedAt);
        expect(series.isDeleted, isTrue);
        expect(series.isGenerationEnabled, isFalse);
      });

      test('rejects deletion before creation', () {
        // Given
        final deletedAt = DateTime.utc(2025, 12, 31);

        // When
        TransactionSeries construct() {
          return _series(deletedAt: deletedAt);
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'deletedAt',
            ),
          ),
        );
      });

      test('rejects deletion before archival', () {
        // Given
        final archivedAt = DateTime.utc(2026, 3, 1);
        final deletedAt = DateTime.utc(2026, 2, 1);

        // When
        TransactionSeries construct() {
          return _series(
            archivedAt: archivedAt,
            deletedAt: deletedAt,
            modifiedAt: archivedAt,
          );
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'deletedAt',
            ),
          ),
        );
      });

      test('accepts deletion at or after archival', () {
        // Given
        final archivedAt = DateTime.utc(2026, 2, 1);
        final deletedAt = DateTime.utc(2026, 3, 1);

        // When
        final series = _series(
          archivedAt: archivedAt,
          deletedAt: deletedAt,
          modifiedAt: deletedAt,
        );

        // Then
        expect(series.isArchived, isTrue);
        expect(series.isDeleted, isTrue);
        expect(series.isGenerationEnabled, isFalse);
      });
    });

    group('pause', () {
      test('rejects pausing a deleted series', () {
        // Given
        final deletedAt = DateTime.utc(2026, 2, 1);
        final series = _series(deletedAt: deletedAt, modifiedAt: deletedAt);

        // When
        TransactionSeries action() {
          return series.pause(modifiedAt: DateTime.utc(2026, 2, 2));
        }

        // Then
        expect(
          action,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'A deleted transaction series cannot be paused.',
            ),
          ),
        );
      });
    });

    group('resume', () {
      test('rejects resuming an archived series', () {
        // Given
        final archivedAt = DateTime.utc(2026, 2, 1);
        final series = _series(archivedAt: archivedAt, modifiedAt: archivedAt);

        // When
        TransactionSeries action() {
          return series.resume(modifiedAt: DateTime.utc(2026, 2, 2));
        }

        // Then
        expect(
          action,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'An archived transaction series cannot be resumed.',
            ),
          ),
        );
      });

      test('rejects resuming a deleted series', () {
        // Given
        final deletedAt = DateTime.utc(2026, 2, 1);
        final series = _series(deletedAt: deletedAt, modifiedAt: deletedAt);

        // When
        TransactionSeries action() {
          return series.resume(modifiedAt: DateTime.utc(2026, 2, 2));
        }

        // Then
        expect(
          action,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'A deleted transaction series cannot be resumed.',
            ),
          ),
        );
      });
    });
  });
}

TransactionSeries _series({
  TransactionTemplate? template,
  RecurrenceRule? recurrenceRule,
  List<RecurrenceException> exceptions = const [],
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return TransactionSeries(
    id: TransactionSeriesId.fromString('series-1'),
    template: template ?? _template('normal'),
    recurrenceRule: recurrenceRule ?? _monthlyRule(),
    exceptions: exceptions,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: 1,
  );
}

RecurrenceRule _monthlyRule() {
  return RecurrenceRule(
    startsOn: CalendarDate(2026, 1, 1),
    frequency: RecurrenceFrequency.monthly,
  );
}

TransactionTemplate _template(
  String description, {
  TransactionKind kind = TransactionKind.expense,
  AssetAmount? primaryAmount,
  List<LedgerEntry>? ledgerEntries,
}) {
  final amount = primaryAmount ?? _outgoingAmount('100');

  return TransactionTemplate(
    kind: kind,
    merchantId: MerchantId.self,
    description: description,
    splits: const [],
    ledgerEntries: ledgerEntries ?? [_entry(amount)],
  );
}

AssetAmount _outgoingAmount(String value, {AssetId? assetId}) {
  return AssetAmount.outgoing(
    assetId: assetId ?? AssetId.fromString('asset-chf'),
    amount: Decimal.parse(value),
  );
}

AssetAmount _incomingAmount(String value, {AssetId? assetId}) {
  return AssetAmount.incoming(
    assetId: assetId ?? AssetId.fromString('asset-chf'),
    amount: Decimal.parse(value),
  );
}

LedgerEntry _entry(AssetAmount amount) {
  return LedgerEntry(
    accountId: AccountId.fromString('account-1'),
    transactionAmount: amount,
    accountAmount: amount,
    valuationAmount: amount,
    role: LedgerEntryRole.primary,
  );
}

RecurrenceRule _amountRule([RecurrenceAmountEnd? amountEnd]) {
  return RecurrenceRule(
    startsOn: CalendarDate(2026, 1, 1),
    frequency: RecurrenceFrequency.monthly,
    end: RecurrenceEnd(amount: amountEnd ?? _amountEnd()),
  );
}

RecurrenceAmountEnd _amountEnd({bool outgoing = true}) {
  return RecurrenceAmountEnd(
    targetAmount: outgoing ? _outgoingAmount('300') : _incomingAmount('300'),
    completion: RecurrenceAmountCompletion.exactTarget,
  );
}

Matcher _argumentError({required String name, required String message}) {
  return throwsA(
    isA<ArgumentError>()
        .having((error) => error.name, 'name', name)
        .having((error) => error.message, 'message', message),
  );
}
