import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_color_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_icon_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/form/app_text_form_field.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/presentation/models/jar_form_data.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// Shared create/edit form for jars.
final class JarForm extends StatefulWidget {
  /// Creates a jar form.
  const JarForm({
    required this.initialValue,
    required this.valuationCurrency,
    required this.effectiveDate,
    required this.submitLabel,
    required this.onSubmit,
    this.failure,
    this.submitting = false,
    super.key,
  });

  final JarFormData initialValue;
  final Currency valuationCurrency;
  final CalendarDate effectiveDate;
  final String submitLabel;
  final ValueChanged<JarFormData> onSubmit;
  final PresentationFailure? failure;
  final bool submitting;

  @override
  State<JarForm> createState() => _JarFormState();
}

final class _JarFormState extends State<JarForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetAmountController;

  late JarKind _kind;
  late EntityIcon _icon;
  late EntityColor _color;

  late bool _hasTarget;
  CalendarDate? _targetDate;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialValue.name);
    _descriptionController = TextEditingController(
      text: widget.initialValue.description ?? '',
    );
    _targetAmountController = TextEditingController(
      text: widget.initialValue.targetAmount?.toString() ?? '',
    );

    _kind = widget.initialValue.kind;
    _icon = widget.initialValue.icon;
    _color = widget.initialValue.color;
    _hasTarget = widget.initialValue.targetAmount != null;
    _targetDate = widget.initialValue.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.failure != null) ...[
            _InlineFailure(failure: widget.failure!),
            const SizedBox(height: AppSpacing.medium),
          ],
          AppTextFormField(
            controller: _nameController,
            label: 'Name',
            autofocus: true,
            enabled: !widget.submitting,
            textInputAction: TextInputAction.next,
            validator: (value) {
              final normalized = value?.trim() ?? '';

              if (normalized.isEmpty) {
                return 'Enter a name.';
              }

              if (normalized.length > 100) {
                return 'Use 100 characters or fewer.';
              }

              return null;
            },
          ),
          const SizedBox(height: AppSpacing.medium),
          AppTextFormField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Optional',
            enabled: !widget.submitting,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<JarKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Jar type'),
            items: [
              for (final kind in JarKind.values)
                DropdownMenuItem(value: kind, child: Text(_kindLabel(kind))),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _kind = value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.large),
          Text('Target', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set a target'),
            subtitle: Text(
              'Target amounts use '
              '${widget.valuationCurrency.code.value}.',
            ),
            value: _hasTarget,
            onChanged: widget.submitting
                ? null
                : (value) {
                    setState(() {
                      _hasTarget = value;

                      if (!value) {
                        _targetAmountController.clear();
                        _targetDate = null;
                      }
                    });
                  },
          ),
          if (_hasTarget) ...[
            const SizedBox(height: AppSpacing.small),
            TextFormField(
              controller: _targetAmountController,
              enabled: !widget.submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Target amount',
                suffixText: widget.valuationCurrency.code.value,
              ),
              validator: _validateTargetAmount,
            ),
            const SizedBox(height: AppSpacing.small),
            _TargetDateField(
              date: _targetDate,
              enabled: !widget.submitting,
              effectiveDate: widget.effectiveDate,
              onChanged: (value) {
                setState(() => _targetDate = value);
              },
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.small),
          DropdownButtonFormField<EntityIcon>(
            initialValue: _icon,
            decoration: const InputDecoration(labelText: 'Icon'),
            items: [
              for (final icon in EntityIcon.values)
                DropdownMenuItem(
                  value: icon,
                  child: Row(
                    children: [
                      Icon(
                        EntityIconResolver.resolve(icon),
                        size: AppSize.iconMedium,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Text(_iconLabel(icon)),
                    ],
                  ),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _icon = value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<EntityColor>(
            initialValue: _color,
            decoration: const InputDecoration(labelText: 'Color'),
            items: [
              for (final color in EntityColor.values)
                DropdownMenuItem(
                  value: color,
                  child: Row(
                    children: [
                      _ColorSample(color: color),
                      const SizedBox(width: AppSpacing.small),
                      Text(_colorLabel(color)),
                    ],
                  ),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _color = value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            onPressed: widget.submitting ? null : _submit,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: widget.submitting
                  ? const SizedBox.square(
                      key: ValueKey('progress'),
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.submitLabel, key: const ValueKey('label')),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateTargetAmount(String? value) {
    if (!_hasTarget) {
      return null;
    }

    final result = PresentationFormatters.of(
      context,
    ).numbers.parseDecimal(value ?? '');

    if (result.isFailure) {
      return 'Enter a valid amount.';
    }

    final amount = result.valueOrNull!;

    if (amount <= Decimal.zero) {
      return 'Target amount must be greater than zero.';
    }

    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Decimal? targetAmount;

    if (_hasTarget) {
      final parsed = PresentationFormatters.of(
        context,
      ).numbers.parseDecimal(_targetAmountController.text);

      if (parsed.isFailure) {
        return;
      }

      targetAmount = parsed.valueOrNull!;
    }

    widget.onSubmit(
      JarFormData(
        name: _nameController.text,
        description: _descriptionController.text,
        kind: _kind,
        icon: _icon,
        color: _color,
        sortOrder: widget.initialValue.sortOrder,
        targetAmount: targetAmount,
        targetDate: _targetDate,
      ),
    );
  }
}

final class _TargetDateField extends StatelessWidget {
  const _TargetDateField({
    required this.date,
    required this.enabled,
    required this.effectiveDate,
    required this.onChanged,
  });

  final CalendarDate? date;
  final bool enabled;
  final CalendarDate effectiveDate;
  final ValueChanged<CalendarDate?> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatted = date == null
        ? 'No target date'
        : PresentationFormatters.of(context).dates.date(date!.toDateTimeUtc());

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled
                ? () async {
                    final firstDate = effectiveDate.toDateTimeUtc();

                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date?.toDateTimeUtc() ?? firstDate,
                      firstDate: firstDate,
                      lastDate: DateTime.utc(effectiveDate.year + 100, 12, 31),
                    );

                    if (selected != null) {
                      onChanged(CalendarDate.fromDateTime(selected));
                    }
                  }
                : null,
            icon: const Icon(Icons.event_rounded),
            label: Text(formatted),
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: AppSpacing.xSmall),
          IconButton(
            tooltip: 'Clear target date',
            onPressed: enabled ? () => onChanged(null) : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ],
    );
  }
}

final class _ColorSample extends StatelessWidget {
  const _ColorSample({required this.color});

  final EntityColor color;

  @override
  Widget build(BuildContext context) {
    final palette = EntityColorResolver.resolve(
      color,
      Theme.of(context).brightness,
    );

    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: const SizedBox.square(dimension: 24),
      ),
    );
  }
}

final class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.failure});

  final PresentationFailure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: '${failure.title}. ${failure.message}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failure.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxSmall),
                    Text(
                      failure.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _kindLabel(JarKind kind) {
  return switch (kind) {
    JarKind.savingsGoal => 'Savings goal',
    JarKind.sinkingFund => 'Sinking fund',
    JarKind.reserve => 'Reserve',
  };
}

String _colorLabel(EntityColor color) {
  final name = color.name;

  return '${name[0].toUpperCase()}${name.substring(1)}';
}

String _iconLabel(EntityIcon icon) {
  final name = icon.name;

  return '${name[0].toUpperCase()}${name.substring(1)}';
}
