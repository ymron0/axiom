import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/validation/form_validators.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_color_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_icon_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/form/app_text_form_field.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/presentation/models/account_form_data.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:flutter/material.dart';

/// Editable account form shared by create and edit screens.
///
/// ## Contract
///
/// This widget performs input-shape validation only. Domain and application
/// validation remains authoritative during submission.
final class AccountForm extends StatefulWidget {
  /// Creates an account form.
  const AccountForm({
    required this.custodians,
    required this.assets,
    required this.initialValue,
    required this.submitLabel,
    required this.onSubmit,
    this.failure,
    this.submitting = false,
    super.key,
  });

  final List<Custodian> custodians;
  final List<Asset> assets;
  final AccountFormData initialValue;
  final String submitLabel;
  final ValueChanged<AccountFormData> onSubmit;
  final PresentationFailure? failure;
  final bool submitting;

  @override
  State<AccountForm> createState() => _AccountFormState();
}

final class _AccountFormState extends State<AccountForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _referenceController;
  late final TextEditingController _logoController;

  late CustodianId _custodianId;
  late AssetId _denominationAssetId;
  late AccountKind _kind;
  late EntityLogoSource _logoSource;
  late EntityIcon _icon;
  late EntityColor _color;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialValue;

    _nameController = TextEditingController(text: initial.name);
    _referenceController = TextEditingController(text: initial.reference ?? '');
    _logoController = TextEditingController(text: initial.logoValue ?? '');

    _custodianId = initial.custodianId;
    _denominationAssetId = initial.denominationAssetId;
    _kind = initial.kind;
    _logoSource = initial.logoSource;
    _icon = initial.icon;
    _color = initial.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
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
          DropdownButtonFormField<CustodianId>(
            initialValue: _custodianId,
            decoration: const InputDecoration(labelText: 'Custodian'),
            items: [
              for (final custodian in widget.custodians)
                DropdownMenuItem(
                  value: custodian.id,
                  child: Text(custodian.name),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() => _custodianId = value);
                  },
          ),
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<AssetId>(
            initialValue: _denominationAssetId,
            decoration: const InputDecoration(labelText: 'Denomination asset'),
            items: [
              for (final asset in widget.assets)
                DropdownMenuItem(
                  value: asset.id,
                  child: Text(
                    '${asset.code.value} — ${asset.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() => _denominationAssetId = value);
                  },
          ),
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<AccountKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Account type'),
            items: [
              for (final kind in AccountKind.values)
                DropdownMenuItem(
                  value: kind,
                  child: Text(_accountKindLabel(kind)),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() => _kind = value);
                  },
          ),
          const SizedBox(height: AppSpacing.medium),
          AppTextFormField(
            controller: _referenceController,
            label: 'Reference',
            hint: 'Optional',
            enabled: !widget.submitting,
            textInputAction: TextInputAction.next,
            validator: (value) => FormValidators.maxLength(value, 100),
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
                      Text(_entityIconLabel(icon)),
                    ],
                  ),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() => _icon = value);
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
                      Text(_entityColorLabel(color)),
                    ],
                  ),
                ),
            ],
            onChanged: widget.submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() => _color = value);
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
                    if (value == null) {
                      return;
                    }

                    setState(() => _logoSource = value);
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
          Semantics(
            button: true,
            label: widget.submitLabel,
            child: FilledButton(
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
          ),
        ],
      ),
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    widget.onSubmit(
      AccountFormData(
        name: _nameController.text,
        custodianId: _custodianId,
        denominationAssetId: _denominationAssetId,
        kind: _kind,
        reference: _referenceController.text,
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
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
      ),
    );
  }
}

String _accountKindLabel(AccountKind kind) {
  return switch (kind) {
    AccountKind.cash => 'Cash',
    AccountKind.checking => 'Checking',
    AccountKind.creditCard => 'Credit card',
    AccountKind.cryptoWallet => 'Crypto wallet',
    AccountKind.digitalWallet => 'Digital wallet',
    AccountKind.investment => 'Investment',
    AccountKind.savings => 'Savings',
  };
}

String _entityColorLabel(EntityColor color) {
  final value = color.name;

  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _entityIconLabel(EntityIcon icon) {
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
