import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/application/commands/create_jar_command.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';

/// Editable presentation values for a jar.
///
/// ## Semantics
///
/// Target editing represents the target effective from the current application
/// date. Historical target configurations are preserved when editing.
///
/// Future target configurations are also preserved. A newly edited current
/// target ends immediately before the next existing future target.
///
/// ## Contract
///
/// Presentation validation must occur before converting this value to a
/// creation command or updated domain entity.
final class JarFormData {
  /// Creates editable jar values.
  const JarFormData({
    required this.name,
    required this.description,
    required this.kind,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.targetAmount,
    required this.targetDate,
  });

  final String name;
  final String? description;
  final JarKind kind;
  final EntityIcon icon;
  final EntityColor color;
  final int sortOrder;

  /// Current target amount in the valuation currency.
  ///
  /// `null` means the jar has no target effective from the form's effective
  /// date.
  final Decimal? targetAmount;

  /// Optional desired completion date for the current target.
  final CalendarDate? targetDate;

  /// Creates editable values from [jar].
  ///
  /// Only the target effective on [asOf] is exposed as the editable current
  /// target. Historical and future targets remain owned by [jar] and are
  /// preserved by [applyTo].
  factory JarFormData.fromJar(Jar jar, {required CalendarDate asOf}) {
    final target = jar.targetAt(asOf);

    return JarFormData(
      name: jar.name,
      description: jar.description,
      kind: jar.kind,
      icon: jar.icon,
      color: jar.color,
      sortOrder: jar.sortOrder,
      targetAmount: target?.amount.amount,
      targetDate: target?.targetDate,
    );
  }

  /// Converts these values into a jar creation command.
  CreateJarCommand toCreateCommand({
    required Currency valuationCurrency,
    required CalendarDate effectiveDate,
  }) {
    return CreateJarCommand(
      name: name.trim(),
      description: _normalizedOptional(description),
      kind: kind,
      targets: _newTarget(
        valuationCurrency: valuationCurrency,
        effectiveDate: effectiveDate,
        effectiveUntil: null,
      ),
      icon: icon,
      color: color,
      sortOrder: sortOrder,
    );
  }

  /// Applies these values to [jar].
  ///
  /// Identity and lifecycle metadata remain unchanged.
  ///
  /// Target history before [effectiveDate] is retained. A target overlapping
  /// [effectiveDate] is closed on that date. Existing future targets remain
  /// unchanged.
  Jar applyTo(
    Jar jar, {
    required Currency valuationCurrency,
    required CalendarDate effectiveDate,
    required DateTime modifiedAt,
  }) {
    return Jar(
      id: jar.id,
      name: name.trim(),
      description: _normalizedOptional(description),
      kind: kind,
      targets: _mergeTargets(
        jar.targets,
        valuationCurrency: valuationCurrency,
        effectiveDate: effectiveDate,
      ),
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      archivedAt: jar.archivedAt,
      deletedAt: jar.deletedAt,
      createdAt: jar.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: jar.entityVersion,
    );
  }

  List<JarTarget> _mergeTargets(
    List<JarTarget> existing, {
    required Currency valuationCurrency,
    required CalendarDate effectiveDate,
  }) {
    final sorted = [...existing]
      ..sort((left, right) {
        return left.effectiveFrom.compareTo(right.effectiveFrom);
      });

    final retainedPast = <JarTarget>[];
    final retainedFuture = <JarTarget>[];

    for (final target in sorted) {
      if (target.effectiveFrom.isBefore(effectiveDate)) {
        final overlapsEffectiveDate =
            target.effectiveUntil == null ||
            target.effectiveUntil!.isAfter(effectiveDate);

        if (overlapsEffectiveDate) {
          retainedPast.add(
            JarTarget(
              amount: target.amount,
              effectiveFrom: target.effectiveFrom,
              effectiveUntil: effectiveDate,
              targetDate: target.targetDate,
            ),
          );
        } else {
          retainedPast.add(target);
        }

        continue;
      }

      if (target.effectiveFrom.isAfter(effectiveDate)) {
        retainedFuture.add(target);
      }

      // A target already starting exactly on effectiveDate is deliberately
      // replaced by the edited form value.
    }

    final nextFutureDate = retainedFuture.isEmpty
        ? null
        : retainedFuture.first.effectiveFrom;

    final result = <JarTarget>[
      ...retainedPast,
      ..._newTarget(
        valuationCurrency: valuationCurrency,
        effectiveDate: effectiveDate,
        effectiveUntil: nextFutureDate,
      ),
      ...retainedFuture,
    ];

    result.sort((left, right) {
      return left.effectiveFrom.compareTo(right.effectiveFrom);
    });

    return List.unmodifiable(result);
  }

  List<JarTarget> _newTarget({
    required Currency valuationCurrency,
    required CalendarDate effectiveDate,
    required CalendarDate? effectiveUntil,
  }) {
    final amount = targetAmount;

    if (amount == null) {
      return const [];
    }

    return [
      JarTarget(
        amount: AssetAmount.incoming(
          assetId: valuationCurrency.id,
          amount: amount,
        ),
        effectiveFrom: effectiveDate,
        effectiveUntil: effectiveUntil,
        targetDate: targetDate,
      ),
    ];
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
