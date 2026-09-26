import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/validation/form_validators.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_color_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_icon_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/form/app_text_form_field.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/presentation/models/custodian_form_data.dart';
import 'package:flutter/material.dart';

/// Shared create/edit form for custodians.
final class CustodianForm extends StatefulWidget {
  /// Creates a custodian form.
  const CustodianForm({
    required this.initialValue,
    required this.submitLabel,
    required this.onSubmit,
    this.failure,
    this.submitting = false,
    super.key,
  });

  final CustodianFormData initialValue;
  final String submitLabel;
  final ValueChanged<CustodianFormData> onSubmit;
  final PresentationFailure? failure;
  final bool submitting;

  @override
  State<CustodianForm> createState() => _CustodianFormState();
}

final class _CustodianFormState extends State<CustodianForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _logoController;

  late CustodianKind _kind;
  late EntityLogoSource _logoSource;
  late EntityIcon _icon;
  late EntityColor _color;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.initialValue.name);
    _logoController = TextEditingController(
      text: widget.initialValue.logoValue ?? '',
    );

    _kind = widget.initialValue.kind;
    _logoSource = widget.initialValue.logoSource;
    _icon = widget.initialValue.icon;
    _color = widget.initialValue.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoController.dispose();
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
            validator: (value) => FormValidators.combine<String>([
              FormValidators.requiredText,
              (value) => FormValidators.maxLength(value, 100),
            ])(value),
          ),
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<CustodianKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Custodian type'),
            items: [
              for (final kind in CustodianKind.values)
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
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<EntityLogoSource>(
            initialValue: _logoSource,
            decoration: const InputDecoration(labelText: 'Logo source'),
            items: const [
              DropdownMenuItem(
                value: EntityLogoSource.remote,
                child: Text('Remote image'),
              ),
              DropdownMenuItem(
                value: EntityLogoSource.asset,
                child: Text('Bundled asset'),
              ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _logoSource = value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.medium),
          AppTextFormField(
            controller: _logoController,
            label: _logoSource == EntityLogoSource.remote
                ? 'Logo URL'
                : 'Logo asset path',
            hint: 'Optional',
            enabled: !widget.submitting,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    widget.onSubmit(
      CustodianFormData(
        name: _nameController.text,
        kind: _kind,
        logoSource: _logoSource,
        logoValue: _logoController.text,
        icon: _icon,
        color: _color,
        sortOrder: widget.initialValue.sortOrder,
      ),
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
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      label: '${failure.title}. ${failure.message}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failure.title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxSmall),
                    Text(
                      failure.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
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

String _kindLabel(CustodianKind kind) {
  return switch (kind) {
    CustodianKind.bank => 'Bank',
    CustodianKind.broker => 'Broker',
    CustodianKind.creditProvider => 'Credit provider',
    CustodianKind.digitalWallet => 'Digital wallet',
    CustodianKind.exchange => 'Exchange',
    CustodianKind.selfCustody => 'Self custody',
  };
}

String _colorLabel(EntityColor color) {
  final name = color.name;

  return '${name[0].toUpperCase()}${name.substring(1)}';
}

String _iconLabel(EntityIcon icon) {
  return switch (icon) {
    EntityIcon.accountBalance => 'Bank',
    EntityIcon.accountBalanceWallet => 'Account',
    EntityIcon.savings => 'Savings',
    EntityIcon.payments => 'Payments',
    EntityIcon.creditCard => 'Credit card',
    EntityIcon.wallet => 'Wallet',
    EntityIcon.lock => 'Secure',
    EntityIcon.currencyExchange => 'Exchange',
    EntityIcon.trendingUp => 'Growth',
    EntityIcon.showChart => 'Chart',
    EntityIcon.monitoring => 'Investment',
    EntityIcon.storefront => 'Store',
    EntityIcon.business => 'Business',
    EntityIcon.apartment => 'Institution',
    EntityIcon.public => 'Global',
    EntityIcon.smartphone => 'Digital',
    EntityIcon.token => 'Token',
    EntityIcon.attachMoney => 'Dollar',
    EntityIcon.euro => 'Euro',
    EntityIcon.currencyFranc => 'Franc',
    EntityIcon.other => 'Other',
  };
}
