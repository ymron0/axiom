import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'jar_target.mapper.dart';

/// One effective-dated target configuration for a jar.
///
/// Target history allows a jar's financial objective and desired completion
/// date to change without destroying previous target information.
///
/// ## Date semantics
///
/// [effectiveFrom] is inclusive.
///
/// [effectiveUntil] is exclusive. A `null` value means the target remains in
/// effect indefinitely.
///
/// [targetDate] is the desired completion date for this particular target
/// configuration. It does not determine when the configuration itself stops
/// being effective.
///
/// ## Invariants
///
/// - [amount] must be greater than zero.
/// - [effectiveUntil], when present, must be after [effectiveFrom].
/// - [targetDate], when present, cannot precede [effectiveFrom].
@MappableClass()
final class JarTarget with JarTargetMappable {
  /// The desired monetary target.
  final AssetAmount amount;

  /// The first calendar date on which this target applies.
  final CalendarDate effectiveFrom;

  /// The exclusive end date of this target configuration.
  ///
  /// `null` means the target remains effective indefinitely.
  final CalendarDate? effectiveUntil;

  /// The desired calendar date by which the target should be reached.
  final CalendarDate? targetDate;

  /// Creates an effective-dated jar target.
  @MappableConstructor()
  JarTarget({
    required this.amount,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.targetDate,
  }) {
    if (amount.amount <= Decimal.zero) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Jar target amount must be greater than zero.',
      );
    }

    if (effectiveUntil != null && !effectiveUntil!.isAfter(effectiveFrom)) {
      throw ArgumentError.value(
        effectiveUntil,
        'effectiveUntil',
        'Target effectiveUntil must be after effectiveFrom.',
      );
    }

    if (targetDate != null && targetDate!.isBefore(effectiveFrom)) {
      throw ArgumentError.value(
        targetDate,
        'targetDate',
        'Target date cannot precede effectiveFrom.',
      );
    }
  }

  /// Whether this target applies on [date].
  bool appliesOn(CalendarDate date) {
    if (date.isBefore(effectiveFrom)) {
      return false;
    }

    if (effectiveUntil != null && !date.isBefore(effectiveUntil!)) {
      return false;
    }

    return true;
  }
}
